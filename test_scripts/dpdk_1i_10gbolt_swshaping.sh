#!/bin/bash -ex

DPDK=/home/ubuntu/dpdk
DEVLINK=/home/ubuntu/iproute2/devlink/devlink

source setup/ealopt2.sh

./setup/app_prep.sh

sudo  $DPDK/build/examples/dpdk-qos_sched -l35,36,37,38 -a b3:01.1 -n 8 -- --mnc 35 --cfg $DPDK/examples/qos_sched/scenario1_10gbolt_10gbpon.cfg --pfc 0,0,36,37,38 --rsz 4096,32768,4096 --bsz 128,512,511,511 -i --msz 524288
