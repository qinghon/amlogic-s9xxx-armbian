

# 编译镜像

参考`README.cn.md` 里的`本地化打包` 部分，需要先准备以下

- Armbian 基础镜像 ，通常使用ophub 仓库里做好的，注意使用稳定版release ,链接 [release](https://github.com/ophub/amlogic-s9xxx-armbian/releases)
- `build-armbian/armbian-scripts/common/03-bonuscloud-private` 文件，这个文件主要作用是配置镜像的预制密码之类的，这个文件不要推到镜像仓库里，本地存着就行
- 一个有大存储的arm64 设备，可以用一个arm盒子挂一个外接硬盘，外接硬盘建议btrfs 文件系统，复制快

## 编译过程
- 将此仓库clone到 arm64 设备
- 新建目录`mkdir -p build/output/images`,并将armbian 基础镜像放进去，把`build-armbian/armbian-scripts/common/03-bonuscloud-private` 放到对应目录，记得加上可执行权限
- 执行命令编译镜像, 参考`README.cn.md`， board 类型定义在`build-armbian/armbian-files/common-files/etc/model_database.conf`文件里第14列
```shell
# 指定特定盒子类型
./rebuild -b s912 -s 3072 -k 6.6.30 -t btrfs
# 编译所有差别较大的盒子，注意不是全部，这个定义在`model_database.conf`文件里第15列,
# 定义为`no` 的board 需要上面那样指定来编译
./rebuild -b all -s 3072 -k 6.6.30 -t btrfs
```

### 其他tips

> 编译时可将`rebuild`脚本中`clean_tmp` 函数里压缩命令注释掉加快编译打包，等完全做完后再进行压缩，可以获得更好的压缩率和时间



# 设计
这个仓库是fork https://github.com/ophub/amlogic-s9xxx-armbian 这个仓库来做的，点心云也是基于这个仓库

在这个仓库基础上增加了一个执行自定义命令的步骤，所以编译时需要arm64 平台

执行自定义命令步骤放在镜像替换完内核等操作后，打包压缩前，将需要执行的命令复制到内存，并chroot 到镜像内执行



# 使用

1. 选择设备对应的镜像
2. 烧录至U盘
3. 插入盒子
4. 上电启动，等待自动烧录完成后，盒子自动关机


## 手动安装

1. 选择设备对应的镜像
2. 烧录至U盘
3. 挂载U盘boot 分区
4. 在boot 分区新建`ophub-release`文件，文件内写入`MODEL_ID="-"`
```shell
echo 'MODEL_ID="-"'> ophub-release
```

5. 插入盒子上电启动
6. 登录后执行armbian-install
