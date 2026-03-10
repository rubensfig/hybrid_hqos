#!/bin/bash -ex

DPDK=/home/ubuntu/dpdk
DEVLINK=/home/ubuntu/iproute2/devlink/devlink

source setup/ealopt2.sh
./setup/app_prep.sh

sudo $DPDK/x86_64-native-linuxapp-gcc/examples/dpdk-qos_sched $EALOPTS  -n 8 -- --mnc 35 --cfg $DPDK/examples/qos_sched/profile_100gb_unlimited.cfg --pfc 0,0,36,37 --pfc 1,1,38,39  --rsz 4096,32768,4096 --bsz 128,512,512,511 -i --msz 524288
