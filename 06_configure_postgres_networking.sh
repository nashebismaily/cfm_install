#!/bin/bash
set -euo pipefail

PG_MAJOR="${PG_MAJOR:-16}"
PGDATA_DIR="${PGDATA_DIR:-/var/lib/pgsql/${PG_MAJOR}/data}"
ALLOWED_CIDR="${ALLOWED_CIDR:-127.0.0.1/32}"

LOG_DIR="${LOG_DIR:-/var/log/cloudera-bootstrap}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/06_configure_postgres_networking_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

POSTGRESQL_CONF="${PGDATA_DIR}/postgresql.conf"
PG_HBA_CONF="${PGDATA_DIR}/pg_hba.conf"

if [[ ! -f "$POSTGRESQL_CONF" || ! -f "$PG_HBA_CONF" ]]; then
  echo "Could not find PostgreSQL config in $PGDATA_DIR"
  exit 1
fi

sed -i "s/^#\?listen_addresses.*/listen_addresses = '*'/" "$POSTGRESQL_CONF"

if ! grep -q "$ALLOWED_CIDR" "$PG_HBA_CONF"; then
  cat <<EOF >>"$PG_HBA_CONF"

# Cloudera external access
host    all             all             ${ALLOWED_CIDR}            scram-sha-256
EOF
fi

systemctl restart "postgresql-${PG_MAJOR}"
echo "[OK] PostgreSQL networking configured for ${ALLOWED_CIDR}"
echo "Log file: $LOG_FILE"
