#! /usr/bin/env bash

echo "

  ______                 _ _                                                      
 / _____)               | | |                                                     
( (____  _____ ____   __| | |__   ___ _   _     ___ _____  ____ _   _ _____  ____ 
 \____ \(____ |  _ \ / _  |  _ \ / _ ( \ / )   /___) ___ |/ ___) | | | ___ |/ ___)
 _____) ) ___ | | | ( (_| | |_) ) |_| ) X (   |___ | ____| |    \ V /| ____| |    
(______/\_____|_| |_|\____|____/ \___(_/ \_)  (___/|_____)_|     \_/ |_____)_|    
                                                                                  

"



# Basic info
HOSTNAME=`uname -n`
MAIN_DISK_PARTITION="your-mounting-point-name"
ROOT=`df -Ph | grep $MAIN_DISK_PARTITION | awk '{print $4}{print " / "}{print $2}' | tr -d '\n'`

# System load
MEMORY1=`free -t -m | grep Total | awk '{print $3" MB";}'`
MEMORY2=`free -t -m | grep "Mem" | awk '{print $2" MB";}'`
LOAD1=`cat /proc/loadavg | awk {'print $1'}`
LOAD5=`cat /proc/loadavg | awk {'print $2'}`
LOAD15=`cat /proc/loadavg | awk {'print $3'}`
echo "You are logged in as `whoami`"
echo "
===============================================
 - Hostname............: $HOSTNAME
 - OS..................: `cat /etc/redhat-release`
 - kernel..............: `uname -r`
==============================================
 - Disk Space..........: $ROOT remaining
===============================================
 - CPU usage...........: $LOAD1, $LOAD5, $LOAD15 (1, 5, 15 min)
 - Memory used.........: $MEMORY1 / $MEMORY2
 - Swap in use.........: `free -m | tail -n 1 | awk '{print $3}'` MB
===============================================
"
