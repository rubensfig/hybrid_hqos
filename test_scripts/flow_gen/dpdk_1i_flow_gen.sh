#!/bin/bash -ex

set -ex

# Defaults
DPDK=${DPDK:-/home/ubuntu/dpdk}
DPDK_BUILD=${DPDK_BUILD:-x86_64-native-linuxapp-gcc}
DEVLINK=${DEVLINK:-/home/ubuntu/iproute2/devlink/devlink}

DEFAULT_RULES_BATCH=2000
DEFAULT_RULES_COUNT=$((DEFAULT_RULES_BATCH * 5)) # default = 10000
DEFAULT_NUM_VFS=1
DEFAULT_PCI_BASE="b3:00.0"
DEFAULT_COREMASK="-l35-59"

# Parse CLI args
RULES_COUNT=$DEFAULT_RULES_COUNT
RULES_BATCH=$DEFAULT_RULES_BATCH
NUM_VFS=$DEFAULT_NUM_VFS
PCI_BASE=$DEFAULT_PCI_BASE
COREMASK=$DEFAULT_COREMASK

usage() {
	  echo "Usage: $0 [--rules-count N] [--rules-batch N] [--num-vfs N] [--pci-base ADDR] [--dpdk PATH] [--coremask MASK]"
	    exit 1
    }

while [[ $# -gt 0 ]]; do
	case $1 in
	--rules-count) RULES_COUNT="$2"; shift 2 ;;
	--rules-batch) RULES_BATCH="$2"; shift 2 ;;
	--num-vfs) NUM_VFS="$2"; shift 2 ;;
	--pci-base) PCI_BASE="$2"; shift 2 ;;
  	--dpdk) DPDK="$2"; shift 2 ;;
      	--coremask) COREMASK="$2"; shift 2 ;;
	-h|--help) usage ;;
	*) echo "Unknown option: $1"; usage ;; 
	esac 
done

# Ensure rules count is multiple of batch size
if (( RULES_COUNT % RULES_BATCH != 0 )); then
	echo "Adjusting rules count ($RULES_COUNT) to nearest multiple of batch size ($RULES_BATCH)."
	RULES_COUNT=$(( (RULES_COUNT / RULES_BATCH) * RULES_BATCH ))
fi

# Build VF PCI list
PCI_LIST=()
IFS=".:" read -r BUS DEV FUNC <<< "$PCI_BASE"

for ((i=0; i<NUM_VFS; i++)); do
	VF_DEV=$((DEV + (FUNC + i) / 8))    # increment device ID after .7
	VF_FUNC=$(((FUNC + i) % 8))         # wrap function 0-7
	PCI_LIST+=("$(printf "%s:%02x.%d" "$BUS" "$VF_DEV" "$VF_FUNC")")
done

PCI_ARGS=""
for pci in "${PCI_LIST[@]}"; do
	PCI_ARGS+=" -a $pci"
done

# Setup env
source ../setup/ealopt2.sh
../setup/app_prep.sh

# Run dpdk-test-flow-perf
sudo "$DPDK/$DPDK_BUILD/app/dpdk-test-flow-perf" \
        $COREMASK $PCI_ARGS -n 8 -- \
        --ingress --eth --ipv4 --udp --queue \
        --rules-count="$RULES_COUNT" \
        --rules-batch="$RULES_BATCH" \
        --enable-fwd --rxq=8 --txq=8

