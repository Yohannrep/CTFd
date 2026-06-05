#!/bin/bash

CTID=$1

echo "=================================="
echo "Creating student lab $CTID"
echo "=================================="

# 1. Clone the ttyd-test base template linked-clone style
pct clone 600 $CTID --hostname student-$CTID

# 2. Compute unique IP address based on CTID
LAST_OCTET=$((CTID - 500))
STATIC_IP="10.50.5.${LAST_OCTET}/16"
GATEWAY="10.50.0.1"

echo "Assigning static IP $STATIC_IP via vmbr50..."
pct set $CTID -net0 name=eth0,bridge=vmbr50,ip=${STATIC_IP},gw=${GATEWAY}

# 3. Power on the container
pct start $CTID

# Give Proxmox a brief window to anchor the network link
sleep 2

# 4. Grab the clean IP to echo out to the local console log
IP=$(pct exec $CTID -- ip -4 addr show eth0 | grep inet | awk '{print $2}' | cut -d/ -f1)

echo ""
echo "Lab Started"
echo "CTID: $CTID"
echo "IP Address: $IP"
echo "Expires In: 2 hours"
echo ""

# 5. ASYNCHRONOUS LIFE CYCLE MANAGEMENT
# This forks the destruction process completely away from the active SSH connection string.
# It allows the main script to terminate instantly, giving FastAPI its return code.
(
    sleep 7200
    pct stop $CTID
    pct destroy $CTID
) > /dev/null 2>&1 &

exit 0
