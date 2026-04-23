#!/bin/bash

#export CM_DB_NAME=scm
#export CM_DB_USER=scm
#export CM_DB_PASS='ClouderaCM_2026'
#export DB_HOST=localhost
#export DB_PORT=5432

set -euo pipefail

CM_DB_NAME="${CM_DB_NAME:-scm}"
CM_DB_USER="${CM_DB_USER:-scm}"
CM_DB_PASS="${CM_DB_PASS:-changeme_scm}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

LOG_DIR="${LOG_DIR:-/var/log/cloudera-bootstrap}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/08_prepare_cm_database_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

if [[ ! -x /opt/cloudera/cm/schema/scm_prepare_database.sh ]]; then
  echo "scm_prepare_database.sh not found. Install Cloudera Manager packages first."
  exit 1
fi

if [[ ! -f /usr/share/java/postgresql-connector-java.jar && ! -f /usr/share/java/postgresql.jar ]]; then
  echo "[WARN] PostgreSQL JDBC jar not found in common locations. Verify JDBC availability before continuing."
fi

echo "Running scm_prepare_database.sh"
/opt/cloudera/cm/schema/scm_prepare_database.sh \
postgresql \
"${CM_DB_NAME}" \
"${CM_DB_USER}" \
"${CM_DB_PASS}"

echo "[OK] CM database initialized. Tables created by scm_prepare_database.sh"
echo "Log file: $LOG_FILE"
