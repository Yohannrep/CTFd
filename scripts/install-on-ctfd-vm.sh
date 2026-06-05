#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CTFD_ROOT="${CTFD_ROOT:-/home/cce/CTFd}"
CTFD_THEME_ROOT="${CTFD_ROOT}/CTFd/themes/core"
INSTALL_LIVE_THEME=0
INSTALL_API_SERVICE=0

usage() {
  cat <<'EOF'
Usage:
  bash scripts/install-on-ctfd-vm.sh --install-live-theme
  bash scripts/install-on-ctfd-vm.sh --install-api-service
  bash scripts/install-on-ctfd-vm.sh --docker-up

Environment:
  CTFD_ROOT=/home/cce/CTFd

Options:
  --install-live-theme  Copy Labs files into an existing CTFd checkout and patch navbar.html.
  --install-api-service Install or update the FastAPI /spawn backend as a systemd service.
  --docker-up           Start this project with docker compose.
  --help                Show this help.
EOF
}

patch_live_navbar() {
  local navbar="${CTFD_THEME_ROOT}/templates/components/navbar.html"

  if [[ ! -f "$navbar" ]]; then
    echo "Could not find navbar.html at $navbar" >&2
    exit 1
  fi

  if grep -q 'components/labs_modal.html' "$navbar"; then
    echo "Labs modal include already exists in navbar.html"
    return
  fi

  python3 - "$navbar" <<'PY'
from pathlib import Path
import sys

navbar_path = Path(sys.argv[1])
html = navbar_path.read_text(encoding="utf-8")
labs_markup = """
{# Cyber range Labs controls. #}
<li class="nav-item">
  <button
    id="labs-open-button"
    class="btn btn-sm btn-primary labs-nav-button my-2 my-md-0"
    type="button"
    data-labs-open
  >
    Labs
  </button>
</li>
{% include "components/labs_modal.html" %}
"""

insert_at = html.rfind("</ul>")
if insert_at == -1:
    insert_at = html.rfind("</nav>")

if insert_at == -1:
    html = html.rstrip() + "\n" + labs_markup + "\n"
else:
    html = html[:insert_at] + labs_markup + "\n" + html[insert_at:]

navbar_path.write_text(html, encoding="utf-8")
PY
}

install_live_theme() {
  local backup_dir="${CTFD_ROOT}/backups/labs-$(date +%Y%m%d-%H%M%S)"

  echo "Installing Labs files into $CTFD_THEME_ROOT"
  mkdir -p "$backup_dir"
  mkdir -p "${CTFD_THEME_ROOT}/templates/components"
  mkdir -p "${CTFD_THEME_ROOT}/static/js"
  mkdir -p "${CTFD_THEME_ROOT}/static/css"

  if [[ -f "${CTFD_THEME_ROOT}/templates/components/navbar.html" ]]; then
    cp "${CTFD_THEME_ROOT}/templates/components/navbar.html" "${backup_dir}/navbar.html"
  fi

  cp "${PROJECT_ROOT}/CTFd-custom/themes/core/templates/components/navbar.html" \
    "${CTFD_THEME_ROOT}/templates/components/navbar.html"
  cp "${PROJECT_ROOT}/CTFd-custom/themes/core/templates/components/labs_modal.html" \
    "${CTFD_THEME_ROOT}/templates/components/labs_modal.html"
  cp "${PROJECT_ROOT}/CTFd-custom/themes/core/static/js/labs.js" \
    "${CTFD_THEME_ROOT}/static/js/labs.js"
  cp "${PROJECT_ROOT}/CTFd-custom/themes/core/static/js/labs.js" \
    "${CTFD_THEME_ROOT}/static/js/labs.min.js"
  cp "${PROJECT_ROOT}/CTFd-custom/themes/core/static/css/labs.css" \
    "${CTFD_THEME_ROOT}/static/css/labs.css"
  cp "${PROJECT_ROOT}/CTFd-custom/themes/core/static/css/labs.css" \
    "${CTFD_THEME_ROOT}/static/css/labs.min.css"

  echo "Backup directory: $backup_dir"
  echo "Labs theme install complete."
  echo "Restart CTFd if your deployment does not reload templates automatically."
}

install_api_service() {
  local api_dir="${PROJECT_ROOT}/ctf-api"
  local env_file="${api_dir}/.env"

  echo "Installing FastAPI lab service from $api_dir"

  if [[ ! -f "$env_file" ]]; then
    cp "${api_dir}/.env.example" "$env_file"
    echo "Created $env_file from .env.example. Review it before production use."
  fi

  python3 -m venv "${api_dir}/venv"
  "${api_dir}/venv/bin/pip" install --upgrade pip
  "${api_dir}/venv/bin/pip" install -r "${api_dir}/requirements.txt"

  sudo cp "${PROJECT_ROOT}/deploy/systemd/ctf-api.service" /etc/systemd/system/ctf-api.service
  sudo systemctl daemon-reload
  sudo systemctl enable --now ctf-api.service

  echo "FastAPI lab service installed."
  echo "Check status with: sudo systemctl status ctf-api"
}

docker_up() {
  cd "$PROJECT_ROOT"
  docker compose up -d --build
}

if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-live-theme)
      INSTALL_LIVE_THEME=1
      shift
      ;;
    --install-api-service)
      INSTALL_API_SERVICE=1
      shift
      ;;
    --docker-up)
      docker_up
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$INSTALL_LIVE_THEME" -eq 1 ]]; then
  install_live_theme
fi

if [[ "$INSTALL_API_SERVICE" -eq 1 ]]; then
  install_api_service
fi
