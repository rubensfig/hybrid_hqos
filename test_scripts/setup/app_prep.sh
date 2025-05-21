#!/bin/bash -ex

if [ "$EUID" -ne 0 ]; then
  echo "configure hardware"
  exec sudo -E -s "$0" "$@"
else
  echo "running with sudo"
fi

# NOTE - depends on these predefined environment variables
# - $IFACE
# - $BASEPCI
# - $BRIDGE
# - $BASEMAC

# TODO somehow avoid having externally defined VF0/1/2

# when the interface name has been extended with 'np0', the derived interface names should discard the suffix
BASEIFACE="${IFACE/%np0}"

# MACS=("00:11:22:33:44:00" "00:11:22:33:55:00" "00:11:22:33:44:01" "00:11:22:33:55:01" "00:11:22:33:44:02" "00:11:22:33:55:02" "00:11:22:33:44:03" "00:11:22:33:55:03" "00:11:22:33:44:04" "00:11:22:33:55:04" "00:11:22:33:44:05" "00:11:22:33:55:05" "00:11:22:33:44:06" "00:11:22:33:55:06" "00:11:22:33:44:07" "00:11:22:33:55:07")
MACS=("00:11:22:33:44:00" "00:11:22:33:44:01" "00:11:22:33:44:02" "00:11:22:33:44:03" "00:11:22:33:44:04" "00:11:22:33:44:05" "00:11:22:33:44:06" "00:11:22:33:44:07")

# $BASEMAC is defined in ealopt script
sub_mac() {
  INDEX=$1
  # echo "${BASEMAC/%00/${i}}"
  echo ${MACS[$INDEX]}
}

# 'rep' is short for 'representor'
rep_iface() {
  INDEX=$1
  echo "${BASEIFACE}r${INDEX}"
}

if [ -z "${IFACE}" ]; then
  echo "ENVVAR \$IFACE not set"
  elif [ -z "${BASEMAC}" ]; then
  echo "ENVVAR \$BASEMAC not set"
  elif [ -z "${BRIDGE}" ]; then
  echo "ENVVAR \$BRIDGE not set"
  elif [ -z "${BASEPCI}" ]; then
  echo "ENVVAR \$BASEPCI not set"
else
  # TODO check that irdma is just blacklisted
  modprobe -r irdma
  modprobe -r ice
  modprobe ice
  modprobe vfio-pci
  dpdk-devbind.py --unbind $BASEPCI
  dpdk-devbind.py --bind ice $BASEPCI
  # should now check that the correct (pmdlink patched) ice driver has been loaded

  # echo "module ice +p" > /sys/kernel/debug/dynamic_debug/control

  ip link del dev $GTPDEV || :
  ip link del $BRIDGE || :
  ip link add $BRIDGE type bridge
  ip link set $IFACE master $BRIDGE

  sleep 0.5 # ethernet device takes some time to appear after driver reload

  devlink dev eswitch set pci/$BASEPCI mode switchdev

  echo 8 >/sys/bus/pci/devices/$BASEPCI/sriov_numvfs
  # echo 0 > /sys/bus/pci/devices/$BASEPCI/sriov_drivers_autoprobe
  
  # echo 512 > /sys/bus/pci/devices/$BASEPCI/rss_lut_pf_attr
  # echo 2048 > /sys/bus/pci/devices/$BASEPCI/virtfn0/rss_lut_vf_attr 
  # echo 256 > /sys/bus/pci/devices/$BASEPCI/virtfn0/sriov_vf_msix_count 

  # for i in {1..2}; do
  #   echo 512 > /sys/bus/pci/devices/$BASEPCI/virtfn$i/rss_lut_vf_attr 
  #   echo 64 > /sys/bus/pci/devices/$BASEPCI/virtfn$i/sriov_vf_msix_count 
  # done
  # echo 1 > /sys/bus/pci/devices/$BASEPCI/sriov_drivers_autoprobe

  for i in {0..7}; do
    ip link set $IFACE vf $i mac $(sub_mac $i) spoof off
  done

  ethtool -K $IFACE hw-tc-offload on
  for i in {0..7}; do
    SUBIFACE=$(rep_iface $i)
    ip link set $SUBIFACE master $BRIDGE
    ip link set $SUBIFACE up
    ethtool -K $SUBIFACE hw-tc-offload on
  done

  tc qdisc add dev $IFACE ingress

  for i in {0..7}; do
    SUBMAC=$(sub_mac $i)
    SUBIFACE=$(rep_iface $i)
    tc qdisc add dev $SUBIFACE ingress

    sleep 0.5

    tc filter add dev $SUBIFACE ingress protocol ip flower src_mac $SUBMAC skip_sw action mirred egress redirect dev ${IFACE}
    tc filter add dev ${IFACE} ingress protocol ip flower dst_mac $SUBMAC skip_sw action mirred egress redirect dev $SUBIFACE
  done

  dpdk-devbind.py -b vfio-pci $VF0 $VF1 $VF2 $VF3 $VF4 $VF5 $VF6 $VF7
fi

echo "success"
