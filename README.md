# Cmbackup - Backup & Restore Suite for Carbonio Community Edition (CE)
========================================================================

**Cmbackup** is an enhanced, robust, and production-tested backup and restore suite designed specifically for **Zextras Carbonio Community Edition (CE)**.

Based on the original `zmbackup` / `cmbackup` implementations (Lucas Costa Beyeler, Anahuac Gil, Marco Steinacher), this version (1.3.0) incorporates architectural innovations, performance optimizations, and reliability safeguards developed during large-scale production migrations in **Z2C (Zimbra to Carbonio Migration Suite)**.

[![Carbonio CE](https://img.shields.io/badge/Carbonio%20CE-23.x%20--%2026.x-blue.svg)](https://www.zextras.com/carbonio-community-edition)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04%20|%2024.04%20|%20RHEL%208--9-orange.svg)](https://ubuntu.com/)
[![Release](https://img.shields.io/badge/Release-1.3.0-green.svg)](https://github.com/kit400/cmbkp)
[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](LICENSE)

---

## Key Features & Z2C Enhancements

1. **Pre-Flight Disk Space Safeguards (from Z2C)**:
   - Evaluates free disk space before dumping mailboxes or restoring.
   - Enforces configurable `MIN_FREE_DISK_GB` (default: 5 GB) threshold to prevent filling the partition and crashing Carbonio databases / mailboxd services.

2. **LPT (Longest Processing Time First) Parallel Scheduling (from Z2C)**:
   - Queries mailbox quotas/sizes (`zmprov gqu localhost`) and sorts accounts descending before queuing jobs in GNU Parallel.
   - Largest mailboxes start processing immediately, preventing queue bottlenecks and finishing multi-core backup runs up to **3x faster**.

3. **HTTP 204 No Data & Clean Dumps Detection (from Z2C)**:
   - In incremental routines, detects when Zimbra/Carbonio REST returns HTTP `204 No Data` or empty archives.
   - Automatically skips empty dump creation and purges 0-byte `.tgz` files to keep storage clean.

4. **Mailbox Audit & Message Verification (`--verify` / `-c`)**:
   - Compare and audit live mailbox folder message counts (`zmmailbox -z -m <account> gaf`) before and after backups/restores.

5. **Dry-Run Mode (`--dry-run`)**:
   - Preview backup sessions, affected accounts, and estimated messages without downloading data or altering disk state.

6. **Flexible Configuration & Auto-Detection**:
   - Automatic fallback discovery for OpenLDAP binaries (`/opt/zextras/common/bin`), `zmmailbox`, and `zmlocalconfig`.
   - Auto-resolves `LDAPSERVER`, `LDAPADMIN`, and `LDAPPASS` from Carbonio configuration if left blank.

7. **Configurable REST URL (`ZMMAILBOX_URL`)**:
   - Support for custom endpoints (`https://localhost:7071`, `https://127.0.0.1:8443`, etc.) to prevent socket timeouts and connection refusals.

8. **Modern Installer Support**:
   - Native support for Ubuntu 22.04, 24.04 (Noble Numbat), Debian, and RHEL/Rocky/AlmaLinux 8–9.
   - Unattended non-interactive installation via `./install.sh -y` or `--unattended`.

9. **Modern Unicode Box Tables & Terminal Styling**:
   - Clean Unicode rounded box-drawing tables (`╭───┬───╮`) with status colors (bold green for FINISHED, yellow for IN PROGRESS, red for FAILED).
   - Graceful ASCII fallback for non-UTF8 terminals and clean plain text when piping (`NO_COLOR` and non-TTY support).
   - Deep inspection of individual backup sessions via `cmbackup -l <session_name>`.

---

## Requirements

* **GNU Parallel** (`apt install parallel` or `dnf install parallel`)
* **SQLite3** (`apt install sqlite3` or `dnf install sqlite`)
* **Carbonio CE** (`/opt/zextras` installed and active)

---

## Installation

### Fast Unattended Install (Recommended)

Run as `root` on your Carbonio server:

```bash
git clone https://github.com/kit400/cmbkp.git /tmp/cmbkp
cd /tmp/cmbkp
./install.sh -y
```

### Interactive Install

```bash
cd /tmp/cmbkp
./install.sh
```

To verify installation:

```bash
su - zextras -c "cmbackup -v"
# Output: cmbackup version: 1.3.0
```

---

## Usage Guide

```bash
cmbackup -h
```

### Full Backups (`-f`, `--full`)

```bash
# Backup all active accounts (LDAP + Mailbox)
su - zextras -c "cmbackup -f"

# Backup only specific accounts (comma separated)
su - zextras -c "cmbackup -f -a user1@domain.com,user2@domain.com"

# Backup only a specific domain
su - zextras -c "cmbackup -f -d domain.com"

# Backup only mailboxes (no LDAP)
su - zextras -c "cmbackup -f -m"

# Backup only LDAP entries
su - zextras -c "cmbackup -f -ldp"

# Backup distribution lists or aliases
su - zextras -c "cmbackup -f -dl"
su - zextras -c "cmbackup -f -al"
```

### Incremental Backups (`-i`, `--incremental`)

```bash
# Incremental backup for all accounts (only changes since last backup)
su - zextras -c "cmbackup -i"

# Incremental backup for specific account
su - zextras -c "cmbackup -i user@domain.com"

# Incremental backup with explicit since date
su - zextras -c "cmbackup -i --since 2026-09-01 -a user@domain.com"
```

### Dry-Run Simulation (`--dry-run`)

Test run without transferring data:

```bash
su - zextras -c "cmbackup -i --dry-run"
```

### Mailbox Audit & Verification (`-c`, `--verify`)

Audit live mailbox message counts:

```bash
# Verify specific account
su - zextras -c "cmbackup -c user@domain.com"

# Verify all active accounts
su - zextras -c "cmbackup -c"
```

### Listing & Inspecting Sessions (`-l`, `--list`)

```bash
# List all backup sessions
su - zextras -c "cmbackup -l"
```

Output:
```text
╭─────────────────────────┬────────────┬────────────────────┬──────────┬──────────┬────────────╮
│ Session Name            │ Date       │ Type               │ Accounts │     Size │ Status     │
├─────────────────────────┼────────────┼────────────────────┼──────────┼──────────┼────────────┤
│ distlist-20261001010001 │ 2026-10-01 │ Distribution List  │        1 │     8.0K │ FINISHED   │
│ full-20261001003001     │ 2026-10-01 │ Full Backup        │        2 │     8.4M │ FINISHED   │
│ inc-20261001013001      │ 2026-10-01 │ Incremental Backup │       29 │      26G │ FINISHED   │
╰─────────────────────────┴────────────┴────────────────────┴──────────┴──────────┴────────────╯
  Total: 3 session(s), 32 account(s) backed up in /opt/zextras/backup
```

Inspect accounts inside a specific session:

```bash
# Inspect accounts in a session
su - zextras -c "cmbackup -l full-20261001003001"
```

Output:
```text
  Session Details: full-20261001003001
╭─────┬────────────────────────────────────────────┬────────────┬────────────┬──────────╮
│   # │ Account / Mailbox                          │       Size │ Date       │ Status   │
├─────┼────────────────────────────────────────────┼────────────┼────────────┼──────────┤
│   1 │ root                                       │       4.2M │ 10/01/26   │ OK       │
│   2 │ postmaster                                 │       4.2M │ 10/01/26   │ OK       │
╰─────┴────────────────────────────────────────────┴────────────┴────────────┴──────────╯
  Session: full-20261001003001 | Total Accounts: 2 | Total Size: 8.4M
```

### Restoring Backups (`-r`, `--restore`)

Restore a full session:

```bash
# Restore entire session (LDAP + Mailbox)
su - zextras -c "cmbackup -r full-20260930190000"

# Restore only one account from session
su - zextras -c "cmbackup -r full-20260930190000 user@domain.com"

# Restore an account into a different account (Restore on Account)
su - zextras -c "cmbackup -r -ro full-20260930190000 source@domain.com target@domain.com"
```

### Maintenance & Housekeeping

```bash
# Delete specific session
su - zextras -c "cmbackup -d full-20260930190000"

# Run housekeeper to clean sessions older than ROTATE_TIME days
su - zextras -c "cmbackup -hp"
```

---

## Configuration (`/etc/cmbackup/cmbackup.conf`)

Key parameters in `/etc/cmbackup/cmbackup.conf`:

```ini
BACKUPUSER=zextras
WORKDIR=/opt/zextras/backup
ZMMAILBOX=/opt/zextras/bin/zmmailbox
ZMMAILBOX_URL=https://localhost:7071
MAX_PARALLEL_PROCESS=4
ROTATE_TIME=30
MIN_FREE_DISK_GB=5
SESSION_TYPE=SQLITE3
```

---

## Authors & Credits

* **Lucas Costa Beyeler** - Original author of `zmbackup`
* **Anahuac Gil** - Initial port from `zmbackup` to `cmbackup` for Carbonio CE
* **Marco Steinacher** - PR #1 fixes (ZMMAILBOX_URL, regex expansions, SQLite race conditions)
* **kit400** - Fork maintenance, Z2C architecture integrations, Ubuntu 24.04 compatibility, and v1.3.0 enhancements.
