#!/usr/bin/perl

use strict;

################################################################################
#个人见解:ophub我家云用的f大的调速脚本,我的理解是根据温度的匀速调速脚本,但是我家云
#的情况不太一样,我家云主板上的散热器是一块厚铝合金,实际目的是为了增加cpu的热容,使温
#度不易跳变,由于平时cpu使用频率也很低,温度更多是来自环境温#度和硬盘温度,所以我之前的
#使用爱好是cpu温度低风扇不开启可保证寿命,温度高于65低于75度,风扇低速、低噪音运行,缓
#慢抽走我家云内热风就行,没有必要强制降低cpu温度,当cpu突破75度,风扇全速运行,强制散热.
#由于cpu重负载情况不多,所以风扇很少全速开启.
#这套逻辑使用下来非常满意;
#20240604 增加风扇降噪系数（系数可以是小数），倍数降低风扇温度最高限（最高限默认75度）以下，最低限以上的风扇转速，强调不超温就尽量不让风扇吵闹的原则；
#              修改风扇停转温度，根据硬盘最佳寿命40度为修改参考；
#20240428 增加风扇关闭功能，在冬天气温比较低时，如果风扇还旋转，因为热胀冷缩轴承非常容易磨损，天气冷的时候是风扇损坏率较高的时候。
# 参数我已经修改完善，没有特殊情况勿改 -根据F大脚本修改 by Ran
# cat /sys/devices/virtual/thermal/thermal_zone0/temp #用此行命令可在ssh命令矿中查看cpu实时温度
# 参数调整区 风扇按照固定占空比启动后10s,根据cpu温度调整转速,低于$temp_low风扇停转,高于$temp_fanOn风扇启动。
# 速度最小值(满速是99),如果太小可能进入死区,风扇不转,需配合下面提示调整
my $speed_min = 8;

# 速度最大值(满速是99)
my $speed_max = 99;

# 温度低限(摄氏度): 小于等于此温度风扇停转
my $temp_low = 40;

# 风扇启动温度低限(摄氏度): 大于于等于此值按启动风扇散热
my $temp_fanOn = 65;

# 风扇启动占空比参数(%): 风扇启动时使用固定占空比：风扇启动占空比参数,设置要点:保证能启动同时风扇噪音不要过大
my $duty_cycle_on = 5;

# 降噪系数: 降低风扇启动到cpu温度最高限区间的风扇噪音,降低幅度计算1/$fan_n,最终风扇转速=计算转速*(1/$fan_n)+$speed_min；
my $fan_n = 2;

# 温度最高限(摄氏度): 大于此值按最高速率转动
my $temp_high = 75;

# 调速间隔(秒)
my $interval = 10;
################################################################################
#用到的变量,下面参数勿动
# 风扇状态位:0为关闭,1为开启
my $fanclose_temp = 0;

# 风扇首次启动:0为风扇运转中,1风扇从关闭到开启是第一次运行
my $fan_up = 0;

# 风扇切换温度转换值
my $coeff_temp = 0;

################################################################################

my $fixed_speed = $ARGV[0];
my $period = 25000;
&init;
if( ($fixed_speed ne "") && 
    ($fixed_speed =~ m/^[0-9]{1,3}$/) ) {
    # 如果命令行参数为 0-100 的整数,则按指定的固定速率调速
    &set_fixed_speed($fixed_speed);
} else { 
    # 否则自动调速
    while(1) {
        &auto_speed;
        sleep($interval);    
    }
}
exit 0;

###############################################################################
sub get_soc_temp {
    my @fnames=(
          '/sys/devices/virtual/thermal/thermal_zone0/temp',
          '/sys/devices/platform/scpi/scpi:sensors/hwmon/hwmon0/temp1_input',
       );
    my $fh;
    my $temp = 50;
    for my $fname (@fnames) {
        if( -f $fname ) {
            open $fh, "<", $fname;
            $temp = <$fh> / 1000.0;
            close $fh;
            return $temp;
        }
    }
    return $temp;
}

sub init {

    $speed_max = 100  if ($speed_max > 100);
    $speed_min = 0  if($speed_min < 0);

    my $fh;
    `rmmod pwm_fan 2>/dev/null`;

    open $fh, ">", "/sys/class/pwm/pwmchip0/export";
    print $fh "0\n";
    close $fh;

    open $fh, ">", "/sys/class/pwm/pwmchip0/pwm0/period";
    print $fh "$period\n";
    close $fh;

    open $fh, ">", "/sys/class/pwm/pwmchip0/pwm0/polarity";
    print $fh "normal\n";
    close $fh;

    open $fh, ">", "/sys/class/pwm/pwmchip0/pwm0/enable";
    print $fh "1\n";
    close $fh;
}

sub set_fixed_speed {
    my $fixed_speed = shift;

    # 最大值0.99
    my $coeff_speed = ($fixed_speed / 100.0) > 1 ?  0.99 :($fixed_speed / 100.0);

    #0.1-0.19 定义为死区
    $coeff_speed = 0.20 if $coeff_speed > 0 and $coeff_speed < 0.2;

    my $duty_cycle = int($coeff_speed * $period);

    open my $fh, ">", "/sys/class/pwm/pwmchip0/pwm0/duty_cycle";
    print $fh "$duty_cycle\n";
    close $fh;
}

sub auto_speed {
    my $temp = &get_soc_temp;
    #my $coeff_temp;
    if($temp <= $temp_low) {
	$coeff_temp = 0;
	$fanclose_temp = 0;
	#$fanclose_temp = 1; #去掉此行代码前的#测试风扇是否可以维持旋转,测试完毕此行代码前加#
        } elsif($temp > $temp_high) {
                $coeff_temp = 1;
	              $fanclose_temp = 1;
                } elsif(($temp > $temp_fanOn)&&($fanclose_temp == 0)){
	                       $fan_up = 1; #风扇启转,设置首启转志位
	                       $fanclose_temp = 1;
	                       }else {
                            $coeff_temp = ($temp - $temp_low) / (($temp_high - $temp_low)*$fan_n);
                            }

    my $coeff_speed_min = $speed_min / $speed_max  * ($speed_max / 100);
    my $coeff_speed = $coeff_temp; 
    $coeff_speed = ($coeff_speed_min + $coeff_speed) > 0.99 ? 0.99 :($coeff_speed_min + $coeff_speed);
   
    my $duty_cycle = int($coeff_speed * $period);

    if($fanclose_temp == 0) {
	$duty_cycle = 0;
        }elsif(($fanclose_temp == 1)&&($fan_up == 1)){
		$duty_cycle = $duty_cycle_on ;
		$fan_up = 0; #风扇已启动,清零首启转志位
		}else{
		}
    
    open my $fh, ">", "/sys/class/pwm/pwmchip0/pwm0/duty_cycle";
    print $fh "$duty_cycle\n";
    close $fh;
}
