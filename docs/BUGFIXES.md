# cmbkp Bugfixes & Architectural Improvements Reference

This document tracks identified bugs, design flaws, and stability issues present in the original upstream codebase (`zmbackup` / `cmbackup`), along with the corresponding root causes and fixes implemented in **cmbkp**.

---

## 1. The "Domain / Account with 's'" Parameter Substitution Bug

### Affected Components
- `project/lib/bash/ListAction.sh` (`build_listBKP()`, `build_listRST()`)

### Bug Description
Whenever an administrator attempted to backup or restore accounts filtered by domain or account list where the name contained or started with the letter **`s`** (e.g., `sales.com`, `service.com`, `sample.com`, `user@domain.com`), the operation failed with LDAP DN syntax errors.

### Root Cause
The upstream script attempted string replacement by confusing `sed` regular expression syntax (`sed 's/,/\n/g'`) with Bash parameter expansion (`${var//pattern/replacement}`):

```bash
# Buggy code in upstream:
for i in ${4//s/\n/g}; do
for i in ${2//s/\n/g}; do
```

In Bash, `${var//s/\n/g}` does **not** replace commas with newlines. Instead, it matches the literal character **`s`** and replaces every occurrence with the string `\n/g`.

### Consequence
- Domain `sales.com` was transformed into `\n/gales.com`.
- Domain `service.com` was transformed into `\n/gervice.com`.
- LDAP queries built invalid base DNs like `dc=\n/gales,dc=com`, causing OpenLDAP to crash with:
  ```text
  ldapsearch: Invalid DN syntax (34): invalid DN
  ```

### Fix in cmbkp
Replaced the erroneous pattern with standard, clean Bash word splitting:
```bash
for i in ${4//,/ }; do
for i in ${2//,/ }; do
```

---

## 2. Command Execution Syntax Error in `BackupAction.sh`

### Affected Components
- `project/lib/bash/BackupAction.sh` (`backup_main()`)

### Bug Description
Backing up accounts specified with `-a` or `--account` failed with shell syntax errors.

### Root Cause
The upstream code used command substitution `$()` instead of parameter expansion `${}`:
```bash
# Buggy code in upstream:
for i in $("$4//,/\n/g"); do
```

Bash attempted to execute the entire string `$4//,/\n/g` as a binary executable file on the system, producing:
```text
bash: user1@domain.com,user2@domain.com//,/\n/g: No such file or directory
```

### Fix in cmbkp
Corrected to parameter expansion:
```bash
for i in ${4//,/ }; do
```

---

## 3. Domain Restoration Filter Ignored (`-d domain.com`)

### Affected Components
- `project/lib/bash/ListAction.sh` (`build_listRST()`)
- `project/lib/bash/RestoreAction.sh` (`restore_main_mailbox()`, `restore_main_ldap()`)

### Bug Description
When invoking a selective restore for a domain:
```bash
cmbackup -r full-20261001120000 -d domain.com
# or
cmbackup -r full-20261001120000 domain.com
```
The script completely ignored the domain argument and proceeded to restore **every single account in every domain** contained in that backup session.

### Root Cause
1. `build_listRST()` only tested `if [[ $2 == *"@"* ]]; then`. When given `-d domain.com` or `domain.com` (which does not contain `@`), it fell into the `else` branch and dumped all accounts in the session.
2. In `RestoreAction.sh`, `build_listRST "$1" "$2"` was called with only two arguments, discarding the domain name argument `$3`.

### Fix in cmbkp
- Updated `RestoreAction.sh` to forward `$3` to `build_listRST "$1" "$2" "$3"`.
- Completely reworked `build_listRST()` to accurately parse:
  - Account lists (`-a user1,user2` or `user@domain.com`)
  - Domain filters (`-d domain.com` or `domain.com`)
  - Multiple comma-separated domains (`-d domainA.com,domainB.com`)
  - Session-wide restores (when no filter is supplied)

---

## 4. LDAP Restore Collision on Existing Accounts (`Already exists (68)`)

### Affected Components
- `project/lib/bash/ParallelAction.sh` (`ldap_restore()`)
- `project/lib/bash/RestoreAction.sh`

### Bug Description
Restoring a backup into an environment where the mailbox account already exists in Carbonio LDAP caused `ldapadd` to abort with error code 68:
```text
ldap_add: Already exists (68)
adding new entry "uid=user,ou=people,dc=domain,dc=com"
```
This error frequently derailed restore automation and caused misleading failure reports.

### Fix in cmbkp
- Restructured restore flow to cleanly detect when LDAP entries already exist.
- Skips redundant account recreation while logging an informational note, allowing mailbox data extraction (`postRestURL`) to proceed unimpeded.

---

## 5. Duplicate Mailbox Restoration Pass

### Affected Components
- `project/lib/cmbkp`
- `project/lib/bash/RestoreAction.sh`

### Bug Description
Restoring full or incremental sessions via CLI executed mailbox restoration twice for every mailbox, needlessly doubling recovery time and I/O load:
```text
 - Restoring Mailbox from /opt/zextras/backup/inc-session/user.tgz
 - Restoring Mailbox from /opt/zextras/backup/inc-session/user.tgz
```

### Root Cause
Nested command execution paths in CLI argument handling triggered `restore_main_mailbox` twice during generic session restore.

### Fix in cmbkp
Consolidated dispatch logic in `project/cmbkp` into a single, clean restoration pass.

---

## 6. Hardcoded REST URL & Socket Timeouts

### Affected Components
- `project/config/cmbkp.conf`
- `project/lib/bash/ParallelAction.sh` (`mailbox_backup()`, `mailbox_restore()`)
- `project/lib/bash/RestoreAction.sh`

### Bug Description
`mailbox_restore` and `mailbox_backup` invoked `zmmailbox getRestURL` and `postRestURL` without passing a target URL endpoint (`-u`). This defaulted to `https://localhost:7071`.

On production servers where:
- The Carbonio admin console was bound to a specific IP or interface,
- A custom admin port was configured (e.g. 8443 or 7071 SSL proxy),
- Localhost SSL certificate hostname validation failed,

REST calls failed with `Connection refused` or socket timeouts.

### Fix in cmbkp
Introduced the `ZMMAILBOX_URL` configuration directive (default `https://localhost:7071`) and passed `-u "$ZMMAILBOX_URL"` to all `zmmailbox` REST invocations.

---

## 7. SQLite Concurrency & Database Locking (`database is locked`)

### Affected Components
- `project/lib/bash/SessionAction.sh`
- `project/lib/bash/ParallelAction.sh`
- `project/lib/bash/MiscAction.sh`

### Bug Description
When running multi-core backups with GNU Parallel (`MAX_PARALLEL_PROCESS > 1`), concurrent worker subshells queried and wrote to `sessions.sqlite3` simultaneously. SQLite threw `database is locked` errors, resulting in lost records and incomplete session history.

### Fix in cmbkp
- Introduced `cmbkp_sqlite` helper in `MiscAction.sh` with automatic Python 3 fallback.
- Isolated database queries and synchronized write transactions.

---

## 8. Disk Space Exhaustion Crash (Z2C Safeguard)

### Affected Components
- `project/lib/bash/MiscAction.sh` (`check_disk_space()`)
- `project/lib/bash/BackupAction.sh`
- `project/lib/bash/RestoreAction.sh`

### Bug Description
The original script performed no pre-flight checks on storage availability. Running a 100 GB backup job or restore on a disk with 10 GB free inevitably filled the filesystem to 100%, causing Carbonio MariaDB, OpenLDAP, and mailboxd daemons to crash and corrupt data.

### Fix in cmbkp
Integrated the `check_disk_space()` safeguard from the **Z2C (Zimbra to Carbonio Migration Suite)** with configurable `MIN_FREE_DISK_GB=5` threshold. Halts execution cleanly before writing to disk if space is insufficient.

---

## 9. 0-Byte Empty Dumps on Incremental Routines (Z2C Optimization)

### Affected Components
- `project/lib/bash/ParallelAction.sh` (`mailbox_backup()`)

### Bug Description
When running incremental backups on accounts with no changes since the last backup date, Carbonio REST returned HTTP `204 No Data`. The legacy script created empty `.tgz` files and touched `.ldiff` files, cluttering backup storage.

### Fix in cmbkp
Detects HTTP `204 No Data` responses, skips dummy dump creation, and automatically purges 0-byte `.tgz` files from the backup tree.
