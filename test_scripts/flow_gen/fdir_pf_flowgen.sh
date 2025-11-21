dd_fdir_rules.sh
#
# Adds 30,000 Intel Flow Director (FDIR) rules using ethtool -N.
# Usage: sudo ./add_fdir_rules.sh <interface>

set -euo pipefail

IFACE=${1:-""}
if [[ -z "$IFACE" ]]; then
	  echo "Usage: $0 <interface>"
	    exit 1
fi

TOTAL_RULES=30000
NUM_QUEUES=16
RULES_PER_QUEUE=$((TOTAL_RULES / NUM_QUEUES))
COUNT=0

echo "🧠 Setting up $TOTAL_RULES FDIR rules on $IFACE across $NUM_QUEUES queues..."
echo

# Make sure Flow Director is enabled
echo "→ Enabling Flow Director on $IFACE"
ethtool -K "$IFACE" ntuple on || {
	  echo "❌ Failed to enable ntuple filtering (Flow Director)."
  exit 1
}

# Clean any existing filters
echo "→ Clearing existing FDIR rules..."
for q in $(seq 0 $((NUM_QUEUES - 1))); do
	  ethtool -N "$IFACE" delete $q 2>/dev/null || true
  done

  echo "→ Adding rules..."
  sleep 1

  for ((q = 0; q < NUM_QUEUES; q++)); do
for ((r = 0; r < RULES_PER_QUEUE; r++)); do
SRC_IP="10.$((r / 256)).$((r % 256)).$q"
DST_IP="192.168.$q.$((r % 256))"
SRC_PORT=$((10000 + r))
DST_PORT=$((20000 + r))

# Example: match UDP traffic based on IP/port and direct to queue q
ethtool -N "$IFACE" flow-type udp4 src-ip "$SRC_IP" dst-ip "$DST_IP" src-port "$SRC_PORT" dst-port "$DST_PORT" action "$q" # 2>/dev/null || true

COUNT=$((COUNT + 1))

if (( COUNT % 500 == 0 )); then
echo "   → $COUNT rules added..."
fi

# Throttle every 2000 to reduce CPU load
if (( COUNT % 2000 == 0 )); then
sleep 0.3
fi
done
done

echo
echo "✅ Completed adding $COUNT FDIR rules on $IFACE."
echo "You can verify with:  ethtool -n $IFACE"

