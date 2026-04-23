#!/bin/bash
set -euo pipefail

MANAGER_HOST="${1:-}"

LOG_DIR="${LOG_DIR:-/var/log/cloudera-bootstrap}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/11_configure_cm_agent_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

if [[ -z "$MANAGER_HOST" ]]; then
  echo "Usage: sudo bash 11_configure_cm_agent.sh <manager-hostname>"
  exit 1
fi

CONFIG_FILE="/etc/cloudera-scm-agent/config.ini"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "$CONFIG_FILE not found. Install cloudera-manager-agent first."
  exit 1
fi

if grep -q "^server_host=" "$CONFIG_FILE"; then
  sed -i "s/^server_host=.*/server_host=${MANAGER_HOST}/" "$CONFIG_FILE"
else
  echo "server_host=${MANAGER_HOST}" >> "$CONFIG_FILE"
fi

systemctl enable cloudera-scm-agent
systemctl restart cloudera-scm-agent

echo "[OK] Agent configured to point at ${MANAGER_HOST}"
echo "Log file: $LOG_FILE"
