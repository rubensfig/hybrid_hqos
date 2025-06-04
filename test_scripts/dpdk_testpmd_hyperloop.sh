#!/bin/bash -ex

VPP=/home/ubuntu/vagf_vpp
DPDK=/home/ubuntu/dpdk
DEVLINK=/home/ubuntu/iproute2/devlink/devlink

source setup/ealopt2.sh

./setup/app_prep.sh

# BUGGY: always seeing packet loss at VF0 Rx

tc filter del dev enp179s0 ingress
tc filter del dev enp179s0r0 ingress
tc filter del dev enp179s0r1 ingress

tc filter add dev enp179s0 ingress protocol ip flower dst_mac 00:11:22:33:44:00 skip_sw action mirred egress redirect dev enp179s0r0
tc filter add dev enp179s0r0 ingress protocol ip flower dst_mac 00:11:22:33:44:01 skip_sw action mirred egress redirect dev enp179s0r1
tc filter add dev enp179s0r1 ingress protocol ip flower src_mac 00:11:22:33:44:01 skip_sw action mirred egress redirect dev enp179s0


$DPDK/build/app/dpdk-testpmd -l35,36,37,38,39 -a b3:01.0 -n 8 -m 10000 --file-prefix j1 -- -a --port-topology=loop --forward-mode=mac --eth-peer=0,00:11:22:33:44:01 --rxd=1024 --txd=1024

# $DPDK/build/app/dpdk-testpmd -l45,46,47,48,49 -a b3:01.1 -n 8 -m 10000 --file-prefix j2 -- -a --port-topology=loop --forward-mode=macswap --rxd=1024 --txd=1024
