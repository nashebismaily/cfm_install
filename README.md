# Cloudera Manager 7.13.2 + CFM 4.12 NiFi/NiFi Registry Installation Runbook

This README documents the working installation flow for deploying Cloudera Manager, PostgreSQL, Cloudera Flow Management, NiFi, and NiFi Registry on RHEL 9.

It combines the scripted bootstrap process with the manual Cloudera Manager UI settings that were required to get NiFi and NiFi Registry working, including PostgreSQL connectivity, CFM parcels, Java settings, TLS/HTTPS, anonymous bootstrap authentication, and NiFi Registry database configuration.

---

## 1. Target Architecture

### Manager / Server Node

The manager node hosts:

- Cloudera Manager Server
- Cloudera Manager Agent
- PostgreSQL 14
- Cloudera Manager databases
- NiFi Registry database
- CFM CSD files
- Cloudera Manager UI

Expected runtime:

- Java 17 for Cloudera Manager
- PostgreSQL 14
- RHEL 9.x
- x86_64 architecture

### Agent / NiFi Nodes

The agent nodes host:

- Cloudera Manager Agent
- NiFi roles
- NiFi Registry role, if placed there
- CFM runtime components

Expected runtime:

- Java 21 for NiFi and NiFi Registry
- RHEL 9.x
- x86_64 architecture

---

## 2. Script Inventory

The install bundle contains these scripts:

```bash
00_check_connectivity.sh
01_bootstrap_repos.sh
02_install_common_packages.sh
03_configure_os.sh
04_install_role_runtime.sh
05_install_postgres.sh
06_configure_postgres_networking.sh
07_create_cm_and_registry_dbs.sh
08_add_cloudera_repos.sh
09_install_cm_packages.sh
10_configure_cm_agent.sh
11_prepare_cm_database.sh
12_start_cm_services.sh
13_install_cfm_csds.sh
14_validate_ready_state.sh
EXPORTS
```

If uploaded file names contain `(1)` or similar suffixes, ignore that. That is only an upload artifact. The real intended file names are the clean names shown above.

---

## 3. Required Pre-Run Step

Before running the scripts, load the environment variables:

```bash
source ./EXPORTS
```

When running scripts with `sudo`, preserve the exported variables:

```bash
sudo -E bash script_name.sh
```

Do not use plain `sudo bash script_name.sh` when the script depends on values from `EXPORTS`.

---

## 4. Recommended `EXPORTS` File

Use this as the baseline `EXPORTS` file.

```bash
# Cloudera archive credentials
# Fill these in before running repo or CSD install scripts.
export CLOUDERA_REPO_USER=''
export CLOUDERA_REPO_PASS=''

# Cloudera Manager and CFM versions
export CM_VERSION=7.13.2.0
export CFM_VERSION=4.12.0.1

# PostgreSQL
export PG_MAJOR=14
export PGDATA_DIR=/data/postgres14
export ALLOWED_CIDR='10.0.0.0/20'

# Cloudera Manager database
export CM_DB_NAME=scm
export CM_DB_USER=scm
export CM_DB_PASS='ClouderaCM_2026'

# Reports Manager database
export RM_DB_NAME=rman
export RM_DB_USER=rman
export RM_DB_PASS='Rman_DB_2026'

# NiFi Registry database
export REG_DB_NAME=nifireg
export REG_DB_USER=nifireg
export REG_DB_PASS='Registry_DB_2026'

# Database host and port
export DB_HOST=localhost
export DB_PORT=5432

# External repo behavior
export ALLOW_EXTERNAL=true
export ENABLE_PGDG=true
export ENABLE_EPEL=false
```

Important version distinction:

```text
CFM repo/version directory: 4.12.0.1
Installed parcel build path: CFM-4.12.0.1-8
```

So `CFM_VERSION` should be:

```bash
export CFM_VERSION=4.12.0.1
```

Do not set it to:

```bash
export CFM_VERSION=4.12.0.1-8
```

The `-8` belongs in the installed parcel build name and jar names, not in the repository version directory.

---

## 5. Manager / Server Node Install Order

Run these steps on the Cloudera Manager server node.

### 5.1 Load Exports

```bash
source ./EXPORTS
```

Verify important values:

```bash
echo $CM_VERSION
echo $CFM_VERSION
echo $PG_MAJOR
echo $PGDATA_DIR
echo $ALLOWED_CIDR
echo $CM_DB_PASS
echo $REG_DB_PASS
```

### 5.2 Connectivity Check

```bash
sudo -E bash 00_check_connectivity.sh
```

This checks local platform details, command availability, repo reachability, optional Cloudera repo authentication, and optional east-west connectivity.

### 5.3 Install Common Packages

```bash
sudo -E bash 02_install_common_packages.sh
```

This installs common operating system packages, including:

- curl
- wget
- bind-utils
- net-tools
- nmap-ncat
- jq
- chrony
- rng-tools
- Python 3.11
- PostgreSQL Python support

It also attempts to set `/usr/bin/python3` to Python 3.11 when available.

### 5.4 Bootstrap Repositories

```bash
sudo -E bash 01_bootstrap_repos.sh
```

This enables PGDG when `ENABLE_PGDG=true`.

If PGDG does not appear on the first try, rerun the script:

```bash
sudo -E bash 01_bootstrap_repos.sh
```

Validate PGDG:

```bash
dnf repolist | grep -i pgdg
```

### 5.5 Configure OS

```bash
sudo -E bash 03_configure_os.sh
```

This configures OS settings for the Cloudera install, including:

- Disable firewalld by default
- Leave SELinux unchanged unless requested
- Disable Transparent Huge Pages
- Configure sysctl values
- Configure system limits

### 5.6 Install Manager Runtime

```bash
sudo -E bash 04_install_role_runtime.sh manager
```

This installs Java 17 for Cloudera Manager.

Validate:

```bash
java -version
```

### 5.7 Install PostgreSQL

```bash
sudo -E bash 05_install_postgres.sh
```

This installs PostgreSQL 14 and initializes the database directory defined by:

```bash
$PGDATA_DIR
```

Recommended value:

```bash
/data/postgres14
```

Validate:

```bash
systemctl status postgresql-14 --no-pager
ss -plnt | grep 5432
```

### 5.8 Configure PostgreSQL Networking

```bash
sudo -E bash 06_configure_postgres_networking.sh
```

This updates:

```text
postgresql.conf
pg_hba.conf
```

It sets PostgreSQL to listen on all interfaces and allows access from:

```bash
$ALLOWED_CIDR
```

Example:

```bash
10.0.0.0/20
```

Validate:

```bash
ss -plnt | grep 5432
sudo -u postgres psql -c "SELECT version();"
```

### 5.9 Create Cloudera Manager and Registry Databases

```bash
sudo -E bash 07_create_cm_and_registry_dbs.sh
```

This creates:

```text
Database: scm
User: scm

Database: rman
User: rman

Database: nifireg
User: nifireg
```

Validate:

```bash
sudo -u postgres psql -l
```

### 5.10 Add Cloudera Manager Repositories

```bash
sudo -E bash 08_add_cloudera_repos.sh
```

This configures the Cloudera Manager package repository for:

```bash
$CM_VERSION
```

Example:

```bash
7.13.2.0
```

Validate:

```bash
dnf repolist | grep -i cloudera
```

### 5.11 Install Cloudera Manager Packages

```bash
sudo -E bash 09_install_cm_packages.sh manager
```

This installs:

```text
cloudera-manager-server
cloudera-manager-daemons
cloudera-manager-agent
```

### 5.12 Configure Local CM Agent

On the manager server itself, use the local hostname or localhost.

```bash
sudo -E bash 10_configure_cm_agent.sh localhost
```

For production or multi-node installs, using the private DNS name of the manager is often cleaner:

```bash
sudo -E bash 10_configure_cm_agent.sh <manager-private-dns>
```

Validate:

```bash
grep server_host /etc/cloudera-scm-agent/config.ini
```

### 5.13 Prepare the CM Database

```bash
sudo -E bash 11_prepare_cm_database.sh
```

Important: `CM_DB_PASS` must match the password used in `07_create_cm_and_registry_dbs.sh`.

Recommended value:

```bash
export CM_DB_PASS='ClouderaCM_2026'
```

### 5.14 Start Cloudera Manager Services

```bash
sudo -E bash 12_start_cm_services.sh
```

This starts:

```text
cloudera-scm-server
cloudera-scm-agent
```

It waits for CM to listen on:

```text
7180
```

Validate:

```bash
systemctl status cloudera-scm-server --no-pager
systemctl status cloudera-scm-agent --no-pager
ss -plnt | grep 7180
curl -I http://localhost:7180
```

Default login:

```text
admin / admin
```

### 5.15 Install CFM CSDs

```bash
sudo -E bash 13_install_cfm_csds.sh
```

This downloads and installs the NiFi and NiFi Registry CSD jars into:

```bash
/opt/cloudera/csd
```

It then restarts Cloudera Manager Server.

Validate:

```bash
ls -lh /opt/cloudera/csd
systemctl status cloudera-scm-server --no-pager
```

### 5.16 Validate Ready State

```bash
sudo -E bash 14_validate_ready_state.sh
```

---

## 6. Agent / NiFi Node Install Order

Run these steps on each agent or NiFi node.

### 6.1 Load Exports

```bash
source ./EXPORTS
```

### 6.2 Connectivity Check

```bash
sudo -E bash 00_check_connectivity.sh
```

### 6.3 Install Common Packages

```bash
sudo -E bash 02_install_common_packages.sh
```

### 6.4 Bootstrap Repositories

```bash
sudo -E bash 01_bootstrap_repos.sh
```

### 6.5 Configure OS

```bash
sudo -E bash 03_configure_os.sh
```

### 6.6 Install Agent Runtime

```bash
sudo -E bash 04_install_role_runtime.sh agent
```

This installs Java 21 for NiFi and NiFi Registry.

Validate:

```bash
java -version
```

### 6.7 Add Cloudera Repositories

```bash
sudo -E bash 08_add_cloudera_repos.sh
```

### 6.8 Install CM Agent Package

```bash
sudo -E bash 09_install_cm_packages.sh agent
```

### 6.9 Configure Agent to Point to Manager

Use the manager private DNS name or hostname.

```bash
sudo -E bash 10_configure_cm_agent.sh <manager-hostname>
```

Example:

```bash
sudo -E bash 10_configure_cm_agent.sh ip-10-0-7-147.us-east-2.compute.internal
```

Validate:

```bash
grep server_host /etc/cloudera-scm-agent/config.ini
systemctl status cloudera-scm-agent --no-pager
```

### 6.10 Validate Agent Node

```bash
sudo -E bash 14_validate_ready_state.sh
```

---

## 7. Do Not Run These on Agent Nodes

These are manager/server-only scripts:

```bash
05_install_postgres.sh
06_configure_postgres_networking.sh
07_create_cm_and_registry_dbs.sh
11_prepare_cm_database.sh
12_start_cm_services.sh
13_install_cfm_csds.sh
```

---

## 8. Cloudera Manager UI: Add CFM Parcel Repository

After installing the CFM CSDs and restarting Cloudera Manager, add the CFM parcel repository in the Cloudera Manager UI.

Go to:

```text
Cloudera Manager → Parcels → Configuration → Remote Parcel Repository URLs
```

Add:

```text
https://archive.cloudera.com/p/cfm4/4.12.0.1/redhat9/yum/tars/parcel/
```

Then:

1. Save changes
2. Check for new parcels
3. Download the CFM parcel
4. Distribute the CFM parcel
5. Activate the CFM parcel

Expected installed parcel path:

```text
/opt/cloudera/parcels/CFM-4.12.0.1-8/
```

---

## 9. Cloudera Manager UI: Add Services

After activating the CFM parcel, add the services through Cloudera Manager.

Recommended order:

1. ZooKeeper, if not already installed
2. NiFi Registry
3. NiFi

---

## 10. Cloudera Manager UI: NiFi Registry Database Configuration

In:

```text
Cloudera Manager → NiFi Registry → Configuration
```

Set the Registry database configuration as follows.

```text
Database Type: PostgreSQL
JDBC URL: jdbc:postgresql://10.0.7.147:5432/nifireg
Database Driver Class: org.postgresql.Driver
Database Driver Location: /opt/cloudera/cm/lib/postgresql-42.7.2.jar
Database Username: nifireg
Database Password: Registry_DB_2026
Validation Query: SELECT 1
SSL: Disabled
```

Replace the IP address with the private IP of the PostgreSQL/CM server if needed.

Template:

```text
Database Type: PostgreSQL
JDBC URL: jdbc:postgresql://<postgres-server-private-ip>:5432/nifireg
Database Driver Class: org.postgresql.Driver
Database Driver Location: /opt/cloudera/cm/lib/postgresql-42.7.2.jar
Database Username: nifireg
Database Password: Registry_DB_2026
Validation Query: SELECT 1
SSL: Disabled
```

Important: The working JDBC driver path is:

```text
/opt/cloudera/cm/lib/postgresql-42.7.2.jar
```

Do not use the parcel path unless you have separately validated it.

---

## 11. Cloudera Manager UI: NiFi Custom Java Home

For NiFi, configure the custom Java home to Java 21.

In:

```text
Cloudera Manager → NiFi → Configuration
```

Set:

```text
Custom Java Home: /usr/lib/jvm/java-21-openjdk-21.0.10.0.7-1.el9.x86_64
```

If the exact minor version differs, find the installed Java 21 path:

```bash
ls -ld /usr/lib/jvm/java-21-openjdk*
```

Then use the matching path in CM.

---

## 12. NiFi TLS / HTTPS Configuration

In:

```text
Cloudera Manager → NiFi → Configuration
```

Set the following NiFi TLS properties.

```text
nifi.web.https.host=ip-10-0-12-178.us-east-2.compute.internal
nifi.web.https.port=8443

nifi.security.keystore=/opt/cloudera/security/keystore.p12
nifi.security.keystoreType=PKCS12
nifi.security.keystorePasswd=<your password>
nifi.security.keyPasswd=<your password>

nifi.security.truststore=/opt/cloudera/security/truststore.jks
nifi.security.truststoreType=JKS
nifi.security.truststorePasswd=<your password>
```

Replace the host value with the NiFi node hostname.

Template:

```text
nifi.web.https.host=<nifi-hostname>
nifi.web.https.port=8443

nifi.security.keystore=/opt/cloudera/security/keystore.p12
nifi.security.keystoreType=PKCS12
nifi.security.keystorePasswd=<your password>
nifi.security.keyPasswd=<your password>

nifi.security.truststore=/opt/cloudera/security/truststore.jks
nifi.security.truststoreType=JKS
nifi.security.truststorePasswd=<your password>
```

---

## 13. NiFi Anonymous Bootstrap Authentication

For initial bootstrap access, set:

```text
nifi.security.allow.anonymous.authentication=true
nifi.initial.admin.identity=anonymous
```

This allows anonymous initial admin access during the bootstrap process.

---

## 14. NiFi Auto-Generated Node Identities

Set:

```text
nifi.autogen.node.identities=true
nifi.autogen.node.identities.dn.prefix=CN=
nifi.autogen.node.identities.dn.suffix=
```

Important: Leave the suffix blank.

Do not use:

```text
, OU=NIFI
```

That suffix caused an identity collision in the working environment.

Final working state:

```text
nifi.autogen.node.identities.dn.suffix=
```

That means the value is blank.

---

## 15. Regenerate NiFi Authorization State After Major Auth Changes

After major authentication or identity changes, remove the generated NiFi authorization files.

On the NiFi node:

```bash
rm -f /var/lib/nifi/users.xml
rm -f /var/lib/nifi/authorizations.xml
```

Then restart NiFi from Cloudera Manager.

Use this carefully. Removing these files resets the generated users and authorization state.

---

## 16. NiFi Registry TLS / HTTPS Configuration

In:

```text
Cloudera Manager → NiFi Registry → Configuration
```

Set:

```text
nifi.registry.web.https.host=<hostname>
nifi.registry.web.https.port=18443

nifi.registry.security.keystore=/opt/cloudera/security/keystore.p12
nifi.registry.security.keystoreType=PKCS12
nifi.registry.security.keystorePasswd=<password>
nifi.registry.security.keyPasswd=<password>

nifi.registry.security.truststore=/opt/cloudera/security/truststore.jks
nifi.registry.security.truststoreType=JKS
nifi.registry.security.truststorePasswd=<password>

nifi.registry.security.needClientAuth=false
nifi.registry.security.initial.admin.identity=anonymous
```

Replace `<hostname>` with the NiFi Registry host.

---

## 17. Import Cloudera Root CA into Java Truststore

Run this on the node where Java processes need to trust the generated Cloudera certificate chain.

```bash
keytool -importcert \
  -alias cloudera-rootca \
  -file /opt/cloudera/security/rootCA.crt \
  -keystore /usr/lib/jvm/java/lib/security/cacerts \
  -storepass changeit \
  -noprompt
```

If Java is installed in a versioned directory, confirm the correct path:

```bash
readlink -f $(which java)
ls -l /usr/lib/jvm/
```

---

## 18. Python Configuration for NiFi

The working Python command used for NiFi was:

```text
/bin/python3.11
```

In Cloudera Manager, configure the NiFi Python command as:

```text
nifi.python.command=/bin/python3.11
```

Validate on the NiFi node:

```bash
which python3.11
python3.11 --version
```

---

## 19. AWS / Network Requirements

At minimum, make sure the manager and agent nodes can communicate across the required ports.

Common ports used in this setup:

```text
7180   Cloudera Manager UI
7182   Cloudera Manager Agent to Server
5432   PostgreSQL
2181   ZooKeeper
8443   NiFi HTTPS
18443  NiFi Registry HTTPS
```

For PostgreSQL, allow the application subnet CIDR configured in:

```bash
$ALLOWED_CIDR
```

Example:

```text
10.0.0.0/20
```

If using AWS security groups, allow inbound PostgreSQL on port `5432` from the manager/agent security group or the appropriate private subnet CIDR.

---

## 20. Validation Commands

### General Host Validation

```bash
hostname -f
cat /etc/redhat-release
uname -m
python3 --version
java -version
getenforce
systemctl is-active firewalld
cat /sys/kernel/mm/transparent_hugepage/enabled
timedatectl
chronyc tracking
ulimit -n
df -h
```

### Repository Validation

```bash
dnf repolist
dnf repolist | grep -i pgdg
dnf repolist | grep -i cloudera
```

### PostgreSQL Validation

```bash
systemctl status postgresql-14 --no-pager
ss -plnt | grep 5432
sudo -u postgres psql -c "SELECT version();"
sudo -u postgres psql -l
```

Remote test from another node:

```bash
psql -h <postgres-server-private-ip> -U nifireg -d nifireg
```

### Cloudera Manager Validation

```bash
systemctl status cloudera-scm-server --no-pager
systemctl status cloudera-scm-agent --no-pager
ss -plnt | grep 7180
curl -I http://localhost:7180
```

### CSD Validation

```bash
ls -lh /opt/cloudera/csd
```

Expected files include NiFi and NiFi Registry CSD jars.

### Parcel Validation

```bash
ls -ld /opt/cloudera/parcels/CFM*
```

Expected path:

```text
/opt/cloudera/parcels/CFM-4.12.0.1-8/
```

---

## 21. Troubleshooting

### PostgreSQL Connection Fails with "No route to host"

Check whether PostgreSQL is listening only on localhost:

```bash
ss -plnt | grep 5432
```

If you see only:

```text
127.0.0.1:5432
```

then PostgreSQL networking is not configured correctly.

Run:

```bash
sudo -E bash 06_configure_postgres_networking.sh
```

Then validate:

```bash
ss -plnt | grep 5432
```

You should see PostgreSQL listening beyond localhost.

Also verify AWS security group rules allow inbound TCP 5432 from the required private CIDR or security group.

### NiFi Registry Database Authentication Fails

Verify the password used in CM matches:

```bash
$REG_DB_PASS
```

Recommended value:

```text
Registry_DB_2026
```

Test manually:

```bash
psql -h <postgres-server-private-ip> -U nifireg -d nifireg
```

### CM Database Preparation Fails

Verify `CM_DB_PASS` is the same in both:

```text
07_create_cm_and_registry_dbs.sh
11_prepare_cm_database.sh
```

Recommended value:

```text
ClouderaCM_2026
```

Run with:

```bash
source ./EXPORTS
sudo -E bash 11_prepare_cm_database.sh
```

### CFM Parcel Does Not Appear

Check that:

1. CSD jars are installed in `/opt/cloudera/csd`
2. CM server was restarted after installing CSDs
3. The CFM parcel repository URL was added in CM
4. You clicked "Check for New Parcels"

Validate CSDs:

```bash
ls -lh /opt/cloudera/csd
```

Validate CM server:

```bash
systemctl status cloudera-scm-server --no-pager
```

### NiFi Identity Collision

Make sure this is blank:

```text
nifi.autogen.node.identities.dn.suffix=
```

Do not set:

```text
, OU=NIFI
```

After changing identities, remove:

```bash
rm -f /var/lib/nifi/users.xml
rm -f /var/lib/nifi/authorizations.xml
```

Then restart NiFi from CM.

### NiFi or Registry TLS Trust Issue

Import the root CA into the Java truststore:

```bash
keytool -importcert \
  -alias cloudera-rootca \
  -file /opt/cloudera/security/rootCA.crt \
  -keystore /usr/lib/jvm/java/lib/security/cacerts \
  -storepass changeit \
  -noprompt
```

Then restart the affected services.

### Wrong Java Version

Manager should use Java 17.

Agent/NiFi nodes should have Java 21.

Validate:

```bash
java -version
alternatives --display java
ls -ld /usr/lib/jvm/java-21-openjdk*
```

Set the NiFi custom Java home in CM if needed.

---

## 22. Known Manual Steps Not Automated by Scripts

The scripts do not fully automate the following:

1. Adding the CFM parcel repo URL in the CM UI
2. Downloading, distributing, and activating the CFM parcel
3. Adding NiFi and NiFi Registry services through CM
4. Setting the NiFi custom Java home in CM
5. Configuring NiFi Registry database settings in CM
6. Configuring NiFi TLS settings in CM
7. Configuring NiFi Registry TLS settings in CM
8. Importing the Cloudera root CA into Java cacerts
9. Removing `users.xml` and `authorizations.xml` after major auth changes

Document and perform these manually unless automation is added later.

---

## 23. Recommended Full Server Command Block

Use this on the manager/server node.

```bash
source ./EXPORTS

sudo -E bash 00_check_connectivity.sh
sudo -E bash 02_install_common_packages.sh
sudo -E bash 01_bootstrap_repos.sh
sudo -E bash 03_configure_os.sh
sudo -E bash 04_install_role_runtime.sh manager

sudo -E bash 05_install_postgres.sh
sudo -E bash 06_configure_postgres_networking.sh
sudo -E bash 07_create_cm_and_registry_dbs.sh

sudo -E bash 08_add_cloudera_repos.sh
sudo -E bash 09_install_cm_packages.sh manager
sudo -E bash 10_configure_cm_agent.sh localhost

sudo -E bash 11_prepare_cm_database.sh
sudo -E bash 12_start_cm_services.sh
sudo -E bash 13_install_cfm_csds.sh
sudo -E bash 14_validate_ready_state.sh
```

---

## 24. Recommended Full Agent Command Block

Use this on each agent/NiFi node.

```bash
source ./EXPORTS

sudo -E bash 00_check_connectivity.sh
sudo -E bash 02_install_common_packages.sh
sudo -E bash 01_bootstrap_repos.sh
sudo -E bash 03_configure_os.sh
sudo -E bash 04_install_role_runtime.sh agent

sudo -E bash 08_add_cloudera_repos.sh
sudo -E bash 09_install_cm_packages.sh agent
sudo -E bash 10_configure_cm_agent.sh <manager-hostname>

sudo -E bash 14_validate_ready_state.sh
```

---

## 25. Final Checklist

Before calling the deployment complete, confirm:

- [ ] Manager host is RHEL 9 x86_64
- [ ] Agent/NiFi hosts are RHEL 9 x86_64
- [ ] `EXPORTS` was sourced before running scripts
- [ ] `sudo -E` was used for scripts requiring exported values
- [ ] PostgreSQL 14 is running
- [ ] PostgreSQL listens on private network, not only localhost
- [ ] `scm`, `rman`, and `nifireg` databases exist
- [ ] CM database was prepared successfully
- [ ] Cloudera Manager UI opens on port 7180
- [ ] CM agent heartbeats successfully
- [ ] CFM CSD jars are installed in `/opt/cloudera/csd`
- [ ] CFM parcel repo was added in CM
- [ ] CFM parcel was downloaded, distributed, and activated
- [ ] NiFi uses Java 21 custom Java home
- [ ] NiFi Registry database config points to `/opt/cloudera/cm/lib/postgresql-42.7.2.jar`
- [ ] NiFi HTTPS is configured on port 8443
- [ ] NiFi Registry HTTPS is configured on port 18443
- [ ] NiFi autogen node identity suffix is blank
- [ ] `users.xml` and `authorizations.xml` were removed after major auth changes
- [ ] Cloudera root CA was imported into Java cacerts if required
- [ ] NiFi and NiFi Registry start cleanly from Cloudera Manager
