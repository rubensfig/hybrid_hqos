#!/bin/bash -ex

VPP=/home/ubuntu/vagf_vpp
DPDK=/home/ubuntu/dpdk
DEVLINK=/home/ubuntu/iproute2/devlink/devlink

source setup/ealopt2.sh

./setup/app_prep.sh

sudo $VPP/build-root/build-vpp-native/vpp/bin/vpp -c /etc/vpp/startup.conf
sudo  $DPDK/build/examples/dpdk-qos_sched -l35-63 -a b3:01.0 -n 8 -- --mnc 35 --cfg $DPDK/examples/qos_sched/scenario1_100gbolt_100gbpon.cfg --pfc 0,0,36,37,38 --rsz 4096,32768,4096 --bsz 128,512,511,511 -i --msz 524288
