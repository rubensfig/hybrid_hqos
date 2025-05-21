
# following resources exist on saturn with these names...
# 4b:00.0 ens3np0
# 4d:00.0 enp77s0np0
# b1:00.0 ens1np0
# b3:00.0 enp179s0np0

# $BASEMAC is used to configure VF macs deterministically
# It is used both by 'app_prep.sh' and some test code.
# Currently, everything assumes that there is only one interface - 1 PF and ~VFs.
# Only if more than one (e810) (~interface, PF) need this change.
BASEMAC="00:11:22:33:44:00"
BRIDGE="swbridge"
BASEVETH="veth0"

# # the high numbered cores are simply the hyperthread twins of the corresponding lower numbered set
# # it would not make sense for a cache constrained system to use the hyperthreads for any work other than the same task as the primary core
# DPDKDEV="b3:00.0" LINUXDEV="4b:00.0" CORES="40-63,104-127"
# DPDKDEV="4d:00.0" LINUXDEV="b1:00.0" CORES="8-31,72-95"

# convert PCI address to network device names...
pci_to_device() {
  device_dir="/sys/bus/pci/devices/0000:${1}/net"
  if [[ -d  "$device_dir" ]] ; then
    # this form caters for context where the vfs already exist, so 'ls' returns multiple file names.  relies on ordering of ls output
    device_name=$(ls -1 $device_dir | head -1)
    if ip link show ${device_name%% *} >/dev/null ; then
      echo "found device for PCI address ${1} : $device_name" >&2
      echo "$device_name"
    fi
  else
    echo "no device found for PCI address ${1}" >&2
  fi
}

DPDKDEV="b3:00.0" LINUXDEV="4b:00.0" CORES="35-63"

IFACE=$(pci_to_device "$DPDKDEV")
LXIFACE=$(pci_to_device "$LINUXDEV")
BASEPCI=0000:$DPDKDEV
# BASEVFPCI=b3:01
BASEVFPCI=${DPDKDEV/%00.0/01}
BASEVFPCI_2=${DPDKDEV/%00.0/02}

DCF_VF=${BASEVFPCI}.0
VF0=${BASEVFPCI}.0
VF1=${BASEVFPCI}.1
VF2=${BASEVFPCI}.2
VF3=${BASEVFPCI}.3
VF4=${BASEVFPCI}.4
VF5=${BASEVFPCI}.5
VF6=${BASEVFPCI}.6
VF7=${BASEVFPCI}.7
VF8=${BASEVFPCI_2}.0
VF9=${BASEVFPCI_2}.1
VF10=${BASEVFPCI_2}.2
VF11=${BASEVFPCI_2}.3
VF12=${BASEVFPCI_2}.4
VF13=${BASEVFPCI_2}.5
VF14=${BASEVFPCI_2}.6
VF15=${BASEVFPCI_2}.7

EALOPTS="$FILEPREFIX -l${CORES} -a ${VF0} -a ${VF1} -a ${VF2} -a ${VF3} -a ${VF4} -a ${VF5} -a ${VF6} -a ${VF7}"

export LXIFACE IFACE BASEPCI BASEVFPCI BASEVFPCI_2 VF0 VF1 VF2 VF3 VF4 VF5 VF6 VF7 VF8 VF9 VF10 VF11 VF12 VF13 VF14 VF15 EALOPTS BASEMAC BRIDGE BASEVETH 
