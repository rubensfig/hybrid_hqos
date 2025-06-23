#!/bin/bash -ex
#
set -ex

if [ "$EUID" -ne 0 ]; then
  echo "configure hardware"
  exec sudo -E -s ./"$0" "$@"
else
  echo "running with sudo"
fi

MODE=$1     # sriov or memif
NUM_CHAIN=$2  # e.g., 3
BASE_CORE=40
MEM=2000
VPP=/home/ubuntu/vagf_vpp
DPDK=/home/ubuntu/dpdk
DEVLINK=/home/ubuntu/iproute2/devlink/devlink
SOCKET_PATH=/var/run/memif

BASEIFACE="enp179s0"
BASE_PCIS=("b3:01.0" "b3:01.1" "b3:01.2" "b3:01.3" "b3:01.4" "b3:01.5" "b3:01.6" "b3:01.7")
MACS=("00:11:22:33:44:00" "00:11:22:33:44:01" "00:11:22:33:44:02" "00:11:22:33:44:03" "00:11:22:33:44:04" "00:11:22:33:44:05" "00:11:22:33:44:06" "00:11:22:33:44:07")

pkill dpdk-testpmd || :

source setup/ealopt2.sh
./setup/app_prep.sh

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

function tc_rewrite() {
	# ---------- Clear tc filters ----------
	tc filter del dev $IFACE ingress || true
	for ((i=0; i<15; i++)); do
	    SUBIFACE=$(rep_iface $i)
	    tc filter del dev $SUBIFACE ingress || true
	done
	
	# ---------- Add tc filters ----------
	for ((i=0; i<NUM_CHAIN; i++)); do
	    SUBIFACE=$(rep_iface $i)
	    dst_mac=$(sub_mac $((i+1)))
	    next_if=$(rep_iface $((i+1)))
	    tc filter add dev $SUBIFACE ingress protocol ip flower dst_mac $dst_mac skip_sw \
	        action mirred egress redirect dev $next_if
	done

	# Last VF -> root PF redirect for packet return
	last_mac=${MACS[$NUM_CHAIN]}
	last_iface=$(rep_iface $((NUM_CHAIN)))
	tc filter add dev $last_iface ingress protocol ip flower dst_mac 00:00:01:00:00:01  skip_sw \
	    action mirred egress redirect dev $BASEIFACE

	first_mac=${MACS[0]}
	tc filter add dev ${BASEIFACE} ingress protocol ip flower dst_mac $first_mac skip_sw action mirred egress redirect dev ${BASEIFACE}r0
}


function run_testpmd_sriov() {
    local i=$1
    local pci=$2
    local cores="$((BASE_CORE + i * 2)),$((BASE_CORE + i * 2 + 1))"
    local prefix="vf$i"
    local fwd_mode=$3
    local eth_peer_flag=$4

    # rm /tmp/testpmd_${prefix}.log

    tail -f /dev/null | \
    $DPDK/build/app/dpdk-testpmd \
        -l $cores -a $pci -n 8 -m $MEM --file-prefix=$prefix \
        -- -a --port-topology=loop --forward-mode=$fwd_mode \
        $eth_peer_flag --rxd=1024 --txd=1024 --auto-start \
    	> /tmp/testpmd_${prefix}.log 2>&1 & disown
}

function run_testpmd_memif() {
    local i=$1
    local memif_id=$2
    local indev=$3
    local outdev=$4
    local blacklist=$7

    local socket=/tmp/memif$i.sock
    local cores="$((BASE_CORE + i * 2)),$((BASE_CORE + i * 2 + 1))"
    local prefix="memif$i"

    tail -f /dev/null | \
    $DPDK/build/app/dpdk-testpmd \
        -l $cores -n 8 -m $MEM --file-prefix=$prefix $indev $outdev $blacklist \
        -- -a --port-topology=chained --forward-mode=$fwd_mode \
        $out_eth_peer --rxd=1024 --txd=1024 --auto-start \
        > /tmp/testpmd_${prefix}.log 2>&1 &

    sleep 0.5
}

# ========== Launch Logic ==========

if [[ "$MODE" == "sriov" ]]; then
    echo "[INFO] Running in SR-IOV mode with $NUM_CHAIN chains"

    tc_rewrite
    for ((i=0; i<=NUM_CHAIN; i++)); do
        # Determine forward mode
        if [[ $i -eq $((NUM_CHAIN)) ]]; then
            fwd_mode="mac"
            eth_peer_flag="--eth-peer=0,00:00:01:00:00:01"
        else
            fwd_mode="mac"
            eth_peer_flag="--eth-peer=0,${MACS[$i+1]}"
        fi

	run_testpmd_sriov $i ${BASE_PCIS[$i]} ${PEER_MACS[$i]} $fwd_mode $eth_peer_flag
    done
    

elif [[ "$MODE" == "memif" ]]; then
    echo "[INFO] Running in memif mode with $NUM_CHAIN chains"

    for ((i=0; i<=NUM_CHAIN; i++)); do
        echo "Starting testpmd for VF $i (PCI $pci) with core $core and mode $fwd_mode"
	prefix=j$((i + 1))
    	peer_mac=${MACS[$i+1]}    	
	fwd_mode="mac"

    	if [[ $i -eq 0 ]]; then
    	    # First in chain: VF -> memif
    	    in_pci=${BASE_PCIS[0]}
    	    in_dev="-a ${in_pci}"
    	    memif_id=$i
    	    out_dev="--vdev=net_memif${memif_id},id=${memif_id},role=server,socket=/tmp/memif${memif_id}.sock"
    	    out_eth_peer="--eth-peer=1,${peer_mac}"
	    blacklist=""
    	elif [[ $i -eq $((NUM_CHAIN)) ]]; then
    	    # Last in chain: memif -> VF
    	    in_pci=${BASE_PCIS[$((NUM_CHAIN))]}
    	    out_dev="-a ${in_pci}"
    	    memif_id=$((i - 1))
    	    in_dev="--vdev=net_memif${memif_id},id=${memif_id},role=client,socket=/tmp/memif${memif_id}.sock" 
    	    out_eth_peer="--eth-peer=1,00:00:01:00:00:01"
	    blacklist=""
    	else
    	    # Middle: memifN-1 -> memifN
    	    in_id=$((i - 1))
    	    out_id=$i
	    in_dev="--vdev=net_memif${in_id},id=${in_id},role=client,socket=/tmp/memif${in_id}.sock"
	    out_dev="--vdev=net_memif${out_id},id=${out_id},role=server,socket=/tmp/memif${out_id}.sock"
    	    out_eth_peer="--eth-peer=1,$peer_mac"
	    blacklist="-b 0000:b3:01.0 -b 0000:b3:01.1 -b 0000:b3:01.2 -b 0000:b3:01.3 -b 0000:b3:01.4 -b 0000:b3:01.5 -b 0000:b3:01.6 -b 0000:b3:01.7"
    	fi

    	run_testpmd_memif "$i" "$memif_id" "$in_dev" "$out_dev" "$out_eth_peer" "$fwd_mode" "$blacklist"
    done
  
else
    echo "Usage: $0 [sriov|memif] <num_chains>"
    exit 1
fi

