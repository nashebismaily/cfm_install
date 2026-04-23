#!/bin/bash
set -uo pipefail

ROLE="${1:-}"
LOG_DIR="${LOG_DIR:-/var/log/cloudera-bootstrap}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/09_install_cm_packages_${ROLE:-unknown}_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

if [[ "$ROLE" != "manager" && "$ROLE" != "agent" ]]; then
  echo "Usage: sudo bash 10_install_cm_packages.sh [manager|agent]"
  exit 1
fi

FAILED_PACKAGES=()

install_pkg() {
  local pkg="$1"
  if ! dnf install -y "$pkg"; then
    echo "[WARN] Failed to install $pkg"
    FAILED_PACKAGES+=("$pkg")
  fi
}

if [[ "$ROLE" == "manager" ]]; then
  install_pkg cloudera-manager-server
  install_pkg cloudera-manager-daemons
  install_pkg cloudera-manager-agent
fi

if [[ "$ROLE" == "agent" ]]; then
  install_pkg cloudera-manager-agent
fi

if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
  echo "[WARN] Packages that failed: ${FAILED_PACKAGES[*]}"
fi

echo "[OK] CM package installation attempted for role ${ROLE}"
echo "Log file: $LOG_FILE"
