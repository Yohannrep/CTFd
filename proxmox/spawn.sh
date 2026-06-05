#!/usr/bin/env bash
set -euo pipefail

CTID="${1:-}"
TEMPLATE_CTID="${TEMPLATE_CTID:-600}"
CTID_MIN="${LAB_CTID_MIN:-501}"
CTID_MAX="${LAB_CTID_MAX:-599}"
LAB_SECONDS="${LAB_EXPIRES_SECONDS:-7200}"
BRIDGE="${LAB_BRIDGE:-vmbr50}"
GATEWAY="${LAB_GATEWAY:-10.50.0.1}"
NETWORK_PREFIX="${LAB_NETWORK_PREFIX:-10.50.5}"

log() {
  echo "[$(date --iso-8601=seconds)] $*"
}

if [[ ! "$CTID" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 <ctid>" >&2
  exit 64
fi

if (( CTID < CTID_MIN || CTID > CTID_MAX )); then
  echo "CTID $CTID is outside allowed lab range ${CTID_MIN}-${CTID_MAX}" >&2
  exit 64
fi

LAST_OCTET=$((CTID - 500))
STATIC_IP="${NETWORK_PREFIX}.${LAST_OCTET}/16"
CLEAN_IP="${NETWORK_PREFIX}.${LAST_OCTET}"

wait_for_ip() {
  local attempt
  local ip

  for attempt in {1..30}; do
    ip="$(pct exec "$CTID" -- ip -4 addr show eth0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 || true)"
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return 0
    fi
    sleep 2
  done

  return 1
}

schedule_cleanup() {
  (
    sleep "$LAB_SECONDS"
    if pct status "$CTID" >/dev/null 2>&1; then
      pct stop "$CTID" >/dev/null 2>&1 || true
      pct destroy "$CTID" >/dev/null 2>&1 || true
    fi
  ) >/dev/null 2>&1 &
}

log "Creating student lab $CTID"

if pct status "$CTID" >/dev/null 2>&1; then
  log "Container $CTID already exists; reusing it."
  pct start "$CTID" >/dev/null 2>&1 || true
else
  pct clone "$TEMPLATE_CTID" "$CTID" --hostname "student-$CTID"
  pct set "$CTID" -net0 "name=eth0,bridge=${BRIDGE},ip=${STATIC_IP},gw=${GATEWAY}"
  pct start "$CTID"
fi

sleep 2

# Template 600 is expected to contain ttyd. Restart it when systemd is available.
pct exec "$CTID" -- bash -lc 'systemctl restart ttyd >/dev/null 2>&1 || true' || true

IP="$(wait_for_ip || true)"
if [[ -z "$IP" ]]; then
  IP="$CLEAN_IP"
fi

schedule_cleanup

echo ""
echo "Lab Started"
echo "CTID: $CTID"
echo "IP Address: $IP"
echo "Terminal URL: http://${IP}:7681"
echo "Expires In: 2 hours"
echo ""
