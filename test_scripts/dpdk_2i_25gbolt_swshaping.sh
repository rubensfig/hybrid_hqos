#!/bin/bash -ex

DPDK=/home/ubuntu/dpdk
DEVLINK=/home/ubuntu/iproute2/devlink/devlink

source setup/ealopt2.sh
./setup/app_prep.sh

sudo  $DPDK/x86_64-native-linuxapp-gcc/examples/dpdk-qos_sched $EALOPTS  -n 8 -- --mnc 35 --cfg $DPDK/examples/qos_sched/4kpipe_25gb.cfg --pfc 0,0,36,37,38 --pfc 1,1,39,40,41 --rsz 4096,32768,4096 --bsz 128,512,511,511 -i --msz 524288
