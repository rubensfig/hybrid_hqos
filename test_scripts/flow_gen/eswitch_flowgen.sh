#!/bin/bash
#
# add_tc_eswitch_rules.sh
#
# Adds 30,000 tc eSwitch rules using flower filters and mirred redirect actions.
# Usage: sudo ./add_tc_eswitch_rules.sh <main_interface>

set -euo pipefail

IFACE=${1:-""}

if [[ -z "$IFACE" ]]; then
	  echo "Usage: $0 <main_interface>"
	    exit 1
fi

# Mock functions (replace with actual implementations)
sub_mac() {
	  printf "aa:bb:cc:dd:%02x:%02x" $((($1 >> 8) & 0xFF)) $(($1 & 0xFF))
  }

  rep_iface() {
	    echo "${IFACE}r${1}"
    }

    # Initialize ingress qdisc on main interface
    echo "Setting up ingress qdisc on $IFACE"
    tc qdisc add dev "$IFACE" ingress 2>/dev/null || true

    TOTAL_RULES=30000
    NUM_SUBIFS=16
    RULES_PER_SUBIF=$((TOTAL_RULES / NUM_SUBIFS))
    COUNT=0

    echo "Adding $TOTAL_RULES TC rules across $NUM_SUBIFS subinterfaces..."

for ((i = 0; i < NUM_SUBIFS; i++)); do
SUBMAC=$(sub_mac $i)
SUBIFACE=$(rep_iface $i)

echo "Setting up $SUBIFACE (src/dst MAC: $SUBMAC)"
tc qdisc add dev "$SUBIFACE" ingress 2>/dev/null || true

for ((r = 0; r < RULES_PER_SUBIF; r++)); do
# Example variation in MAC per rule for uniqueness
SRC_MAC=$(printf "aa:bb:cc:%02x:%02x:%02x" $i $((r >> 8)) $((r & 0xFF)))

# Add forward (rep -> main) rule
tc filter add dev "$SUBIFACE" ingress protocol ip flower \
src_mac "$SRC_MAC" skip_sw \
action mirred egress redirect dev "$IFACE"  # || true

# Add reverse (main -> rep) rule
tc filter add dev "$IFACE" ingress protocol ip flower \
dst_mac "$SRC_MAC" skip_sw \
action mirred egress redirect dev "$SUBIFACE" # || true

COUNT=$((COUNT + 2))

# Progress feedback every 500 rules
if (( COUNT % 500 == 0 )); then
echo "Added $COUNT rules..."
fi

# Optional throttle
if (( COUNT % 2000 == 0 )); then
sleep 0.3
fi
done
done

echo "✅ Completed adding $COUNT tc rules."

