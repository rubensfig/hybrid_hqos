#!/bin/bash -ex

DPDK=/home/ubuntu/dpdk
DEVLINK=/home/ubuntu/iproute2/devlink/devlink

source setup/ealopt2.sh

./setup/app_prep.sh

sudo  $DPDK/build/examples/dpdk-qos_sched $EALOPTS  -n 8 -- --mnc 35 --cfg $DPDK/examples/qos_sched/scenario1_10gbolt_10gbpon.cfg --pfc 0,0,36,37,38 --pfc 1,1,39,40,41 --pfc 2,2,42,43,44 --pfc 3,3,45,46,47 --pfc 4,4,48,49,50 --pfc 5,5,51,52,53 --pfc 6,6,54,55,56 --pfc 7,7,57,58,59 --rsz 4096,32768,4096 --bsz 128,512,511,511 -i --msz 524288
