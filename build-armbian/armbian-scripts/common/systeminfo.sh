#!/bin/bash


GREEN='\033[0;32m'
NO_COLOR='\033[0m'
LOG_TEXT="${GREEN}%s${NO_COLOR}"

countdown() {
    for i in {60..1}
    do
        echo -n "Next information: $i"
        sleep 1
        echo -ne '\r                              \r'
    done
}

system_info() {
    reset
    printf "${LOG_TEXT}\n" "System information"
    neofetch --disk_show '/' #'/boot/' '/boot/efi'
    echo
}
while :;
do
    system_info
    countdown
done