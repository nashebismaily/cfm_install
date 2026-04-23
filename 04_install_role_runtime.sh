#!/bin/bash
set -uo pipefail

ROLE="${1:-}"
LOG_DIR="${LOG_DIR:-/var/log/cloudera-bootstrap}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/04_install_role_runtime_${ROLE:-unknown}_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

if [[ "$ROLE" != "manager" && "$ROLE" != "agent" ]]; then
  echo "Usage: sudo bash 04_install_role_runtime.sh [manager|agent]"
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

set_java21_default() {
  echo "==== Configuring Java 21 as default ===="

  JAVA21_BIN=$(alternatives --display java 2>/dev/null | awk '/java-21-openjdk/ {print $1}' | head -1)

  if [[ -z "$JAVA21_BIN" ]]; then
    echo "[ERROR] Java 21 not found in alternatives"
    return 1
  fi

  echo "[INFO] Java 21 binary: $JAVA21_BIN"

  alternatives --set java "$JAVA21_BIN"

  JAVAC21_BIN=$(alternatives --display javac 2>/dev/null | awk '/java-21-openjdk/ {print $1}' | head -1)

  if [[ -n "$JAVAC21_BIN" ]]; then
    echo "[INFO] Setting javac to Java 21"
    alternatives --set javac "$JAVAC21_BIN"
  fi

  JAVA_HOME_DIR=$(dirname "$(dirname "$JAVA21_BIN")")

  cat >/etc/profile.d/java21.sh <<EOF
export JAVA_HOME=$JAVA_HOME_DIR
export PATH=\$JAVA_HOME/bin:\$PATH
EOF

  chmod 644 /etc/profile.d/java21.sh

  echo "[OK] Java 21 configured as system default"
}

if [[ "$ROLE" == "manager" ]]; then
  echo "==== Installing Manager Runtime ===="
  install_pkg java-17-openjdk
  install_pkg java-17-openjdk-devel
  echo "[OK] Java 17 install attempted on manager"
fi

if [[ "$ROLE" == "agent" ]]; then
  echo "==== Installing Agent Runtime ===="

  install_pkg java-17-openjdk
  install_pkg java-17-openjdk-devel

  install_pkg java-21-openjdk
  install_pkg java-21-openjdk-devel

  echo "[OK] Java 17 and Java 21 install attempted on agent"

  set_java21_default
fi

if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
  echo "[WARN] Packages that failed: ${FAILED_PACKAGES[*]}"
fi

echo
echo "==== Runtime Validation ===="
java -version
echo
alternatives --display java || true
echo
echo "JAVA_HOME=${JAVA_HOME:-not set}"

echo
echo "Log file: $LOG_FILE"