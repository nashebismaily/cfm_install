#!/bin/bash
set -euo pipefail

LOG_DIR="/var/log/cloudera-bootstrap"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/13_install_cfm_csds_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

CFM_VERSION="${CFM_VERSION:-4.12.0}"
CSD_DIR="/opt/cloudera/csd"

echo "==== Installing CFM CSDs ===="

mkdir -p "$CSD_DIR"

echo "==== Downloading CFM CSD jars ===="

curl -L -o /tmp/CFM.jar \
"https://archive.cloudera.com/p/cfm/4.12.0/redhat9/yum/tars/csd/CFM.jar"

curl -L -o /tmp/NIFI.jar \
"https://archive.cloudera.com/p/cfm/4.12.0/redhat9/yum/tars/csd/NIFI.jar"

curl -L -o /tmp/NIFIREGISTRY.jar \
"https://archive.cloudera.com/p/cfm/4.12.0/redhat9/yum/tars/csd/NIFIREGISTRY.jar"

echo "==== Installing CSDs ===="

cp -f /tmp/*.jar "$CSD_DIR/"

chown cloudera-scm:cloudera-scm "$CSD_DIR"/*.jar
chmod 644 "$CSD_DIR"/*.jar

echo "==== Restarting CM Server ===="

systemctl restart cloudera-scm-server

echo "==== Waiting for restart ===="

sleep 60

echo "==== Installed CSDs ===="

ls -lah "$CSD_DIR"

echo
echo "[OK] CFM CSD installation complete"
echo "Log file: $LOG_FILE"
