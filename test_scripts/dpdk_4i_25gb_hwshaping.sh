#!/bin/bash -ex

DPDK=/home/ubuntu/dpdk
DEVLINK=/home/ubuntu/iproute2/devlink/devlink

source setup/ealopt2.sh
./setup/app_prep.sh

sudo devlink port function rate set pci/0000:b3:00.0/node_5 tx_max 3Gbps

sudo $DPDK/x86_64-native-linuxapp-gcc/examples/dpdk-qos_sched $EALOPTS  -n 8 -- --mnc 35 --cfg $DPDK/examples/qos_sched/4kpipe_25gb.cfg --pfc 0,0,36,37 --pfc 1,1,39,40 --pfc 2,2,42,43 --pfc 3,3,45,46 --rsz 4096,32768,4096 --bsz 128,512,511,511 -i --msz 1048576
