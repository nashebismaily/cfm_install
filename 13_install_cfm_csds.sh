# 13_install_cfm_csds.sh

#export CLOUDERA_REPO_USER='your_cloudera_username'
#export CLOUDERA_REPO_PASS='your_cloudera_password'
#export CFM_VERSION=4.12.0.0

```bash
#!/bin/bash
set -euo pipefail

LOG_DIR="/var/log/cloudera-bootstrap"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/13_install_cfm_csds_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

CFM_VERSION="${CFM_VERSION:-4.12.0.0}"
CSD_DIR="/opt/cloudera/csd"
TMP_DIR="/tmp/cfm-csds"

if [[ -z "${CLOUDERA_REPO_USER:-}" || -z "${CLOUDERA_REPO_PASS:-}" ]]; then
  echo "[ERROR] CLOUDERA_REPO_USER and CLOUDERA_REPO_PASS must be exported"
  exit 1
fi

echo "==== Installing CFM CSDs ===="
echo "CFM_VERSION=${CFM_VERSION}"
echo "CSD_DIR=${CSD_DIR}"

mkdir -p "$CSD_DIR"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

echo "==== Cleaning old temporary downloads ===="
rm -f "$TMP_DIR"/*.jar || true

echo "==== Downloading NiFi CSD ===="
NIFI_JAR="NIFI-2.6.0.4.12.0.0-914.jar"
NIFI_URL="https://archive.cloudera.com/p/cfm4/${CFM_VERSION}/redhat9/yum/tars/parcel/${NIFI_JAR}"

curl -u "$CLOUDERA_REPO_USER:$CLOUDERA_REPO_PASS" -L -o "$NIFI_JAR" "$NIFI_URL"

echo "==== Downloading NiFi Registry CSD ===="
NIFIREG_JAR="NIFIREGISTRY-2.6.0.4.12.0.0-914.jar"
NIFIREG_URL="https://archive.cloudera.com/p/cfm4/${CFM_VERSION}/redhat9/yum/tars/parcel/${NIFIREG_JAR}"

curl -u "$CLOUDERA_REPO_USER:$CLOUDERA_REPO_PASS" -L -o "$NIFIREG_JAR" "$NIFIREG_URL"

echo "==== Validating downloads ===="
for f in "$NIFI_JAR" "$NIFIREG_JAR"; do
  if [[ ! -f "$f" ]]; then
    echo "[ERROR] Missing download: $f"
    exit 1
  fi

  SIZE=$(stat -c%s "$f")

  if [[ "$SIZE" -lt 50000 ]]; then
    echo "[ERROR] File too small and likely invalid: $f (${SIZE} bytes)"
    head -20 "$f" || true
    exit 1
  fi

  echo "[OK] Valid file: $f (${SIZE} bytes)"
done

echo "==== Removing old CSD jars ===="
rm -f "$CSD_DIR"/*.jar || true

echo "==== Installing CSD jars ===="
cp -f "$TMP_DIR"/*.jar "$CSD_DIR/"

chown cloudera-scm:cloudera-scm "$CSD_DIR"/*.jar
chmod 644 "$CSD_DIR"/*.jar

echo "==== Installed CSDs ===="
ls -lh "$CSD_DIR"

echo "==== Restarting Cloudera Manager Server ===="
systemctl restart cloudera-scm-server

echo "==== Waiting for CM restart ===="
sleep 90

echo "==== Checking CM port ===="
if ss -plnt | grep -q ":7180"; then
  echo "[OK] Cloudera Manager listening on 7180"
else
  echo "[WARN] CM port 7180 not detected yet"
fi

echo "==== Done ===="
echo "Refresh CM UI and go to Cluster -> Add Service"
echo "You should now see NiFi and NiFi Registry"
echo "Log file: $LOG_FILE"
```

## Required Exports Before Running

```bash
export CLOUDERA_REPO_USER='your_cloudera_username'
export CLOUDERA_REPO_PASS='your_cloudera_password'
export CFM_VERSION=4.12.0.0
```

## Run

```bash
sudo -E bash 13_install_cfm_csds.sh
```
