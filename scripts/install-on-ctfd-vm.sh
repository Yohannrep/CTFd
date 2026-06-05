#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CTFD_ROOT="${CTFD_ROOT:-/home/cce/CTFd}"
CTFD_THEME_ROOT="${CTFD_ROOT}/CTFd/themes/core"
INSTALL_LIVE_THEME=0

usage() {
  cat <<'EOF'
Usage:
  bash scripts/install-on-ctfd-vm.sh --install-live-theme
  bash scripts/install-on-ctfd-vm.sh --docker-up

Environment:
  CTFD_ROOT=/home/cce/CTFd

Options:
  --install-live-theme  Copy Labs files into an existing CTFd checkout and patch navbar.html.
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

  cp "${PROJECT_ROOT}/CTFd/themes/core/templates/components/labs_modal.html" \
    "${CTFD_THEME_ROOT}/templates/components/labs_modal.html"
  cp "${PROJECT_ROOT}/CTFd/themes/core/static/js/labs.js" \
    "${CTFD_THEME_ROOT}/static/js/labs.js"
  cp "${PROJECT_ROOT}/CTFd/themes/core/static/css/labs.css" \
    "${CTFD_THEME_ROOT}/static/css/labs.css"

  patch_live_navbar

  echo "Backup directory: $backup_dir"
  echo "Labs theme install complete."
  echo "Restart CTFd if your deployment does not reload templates automatically."
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
