#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OLD_CTFD_ROOT="${OLD_CTFD_ROOT:-/home/cce/CTFd}"
COMPOSE_DIR="${PROJECT_ROOT}/deploy/ctfd-vm"
CONFIRM="${1:-}"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/reset-ctfd-vm.sh --yes-destroy-clone

This is destructive. It removes the old /home/cce/CTFd checkout/data, stops the
old API service if present, removes old Docker containers/volumes for this app,
and starts a clean CTFd + FastAPI + nginx stack from this Git repo.
EOF
}

if [[ "$CONFIRM" != "--yes-destroy-clone" ]]; then
  usage
  exit 64
fi

echo "Resetting CTFd clone from $PROJECT_ROOT"

if [[ ! -f "${COMPOSE_DIR}/docker-compose.yml" ]]; then
  echo "Missing ${COMPOSE_DIR}/docker-compose.yml" >&2
  exit 1
fi

echo "Stopping old systemd API service if it exists..."
sudo systemctl disable --now ctf-api.service >/dev/null 2>&1 || true
sudo rm -f /etc/systemd/system/ctf-api.service
sudo systemctl daemon-reload

if [[ -f "${OLD_CTFD_ROOT}/docker-compose.yml" ]]; then
  echo "Stopping old /home/cce/CTFd Docker Compose stack..."
  (cd "$OLD_CTFD_ROOT" && sudo docker compose down -v --remove-orphans) || true
fi

echo "Stopping clean repo Docker Compose stack if it already exists..."
(cd "$COMPOSE_DIR" && sudo docker compose down -v --remove-orphans) || true

if [[ -d "$OLD_CTFD_ROOT" ]]; then
  echo "Deleting old CTFd checkout/data at $OLD_CTFD_ROOT"
  sudo rm -rf "$OLD_CTFD_ROOT"
fi

echo "Starting clean CTFd cyber range stack..."
cd "$COMPOSE_DIR"
sudo docker compose up -d --build

echo "Waiting for services..."
sleep 8
sudo docker compose ps

echo ""
echo "Clean rebuild complete."
echo "Open: http://192.168.10.4"
echo "Health: curl http://127.0.0.1/health"
