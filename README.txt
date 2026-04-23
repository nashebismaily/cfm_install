Cloudera Manager 7.13.2.0 + CFM 4.12.0 staging scripts for RHEL 9.7

This corrected set updates the original scripts to:
- avoid brittle premature exits in discovery / check scripts
- cache and reuse dnf repolist output in script 00
- add x86_64 and RHEL 9 validation in script 00
- make package installation scripts log failures per package instead of aborting immediately
- keep DB preparation scripts strict where failure should stop the workflow
- improve agent config handling if server_host is not present yet

Suggested order

Manager node
1. 00_check_connectivity.sh
2. 01_bootstrap_repos.sh
3. 02_install_common_packages.sh
4. 03_configure_os.sh
5. 04_install_role_runtime.sh manager
6. 05_install_postgres.sh
7. 06_configure_postgres_networking.sh
8. 09_add_cloudera_repos.sh
9. 10_install_cm_packages.sh manager
10. 07_create_cm_and_registry_dbs.sh
11. 08_prepare_cm_database.sh
12. 12_validate_ready_state.sh

Agent node
1. 00_check_connectivity.sh
2. 01_bootstrap_repos.sh
3. 02_install_common_packages.sh
4. 03_configure_os.sh
5. 04_install_role_runtime.sh agent
6. 09_add_cloudera_repos.sh
7. 10_install_cm_packages.sh agent
8. 11_configure_cm_agent.sh <manager-hostname>
9. 12_validate_ready_state.sh

Notes
- 00 and 01 are intentionally tolerant and should keep logging even when some checks fail.
- 05 through 09 stay strict in the places where a real failure should stop the install.
- 09 prompts for Cloudera archive credentials unless CLOUDERA_REPO_USER and CLOUDERA_REPO_PASS are already exported.
