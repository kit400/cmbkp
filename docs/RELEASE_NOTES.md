# Release Notes - cmbkp 1.3.0

**Release Date:** October 1, 2026  
**Tag:** `v1.3.0`  
**License:** GNU GPL v2  

---

## Highlights

Version 1.3.0 marks a major milestone for Carbonio Community Edition backup and disaster recovery. It introduces an interactive `fzf`-powered TUI, architectural optimizations ported from the **Z2C (Zimbra to Carbonio Migration Suite)**, pre-flight safety checks, and native support for modern operating systems including Ubuntu 24.04 LTS (Noble Numbat).

---

## What's New in v1.3.0

### 1. Interactive Terminal User Interface (TUI)
- **Fuzzy Search with `fzf`**: Instantly search accounts and backup sessions.
- **Side-by-Side Live Preview Pane**: Inspect live mailbox quota usage, historical backup sessions, and actual archive files on disk.
- **Batch Backups**: Multi-select accounts with <kbd>Tab</kbd> for batch full, incremental, or mailbox-only dumps.
- **Guided Restore Wizard**: Select account, review available restore points, choose original or alternate destination (`-ro`), and confirm execution.
- **Session Explorer**: Browse past backup sessions with contained mailbox previews and jump directly into formatted details tables.

### 2. Z2C Performance Engine & Safeguards
- **LPT (Longest Processing Time First) Scheduling**: Accounts are sorted by quota usage descending (`zmprov gqu`) before entering GNU Parallel workers, eliminating queue bottlenecks and finishing multi-core backup runs up to 3x faster.
- **Pre-Flight Disk Space Safeguards**: Evaluates free disk space against `MIN_FREE_DISK_GB` (default: 5 GB) before dumping data, preventing disk exhaustion from crashing Carbonio services.
- **Clean Dumps & HTTP 204 Handling**: Detects Carbonio REST HTTP `204 No Data` responses, avoiding the creation of empty or 0-byte `.tgz` files.

### 3. Safe Restore Fixes
- Gracefully handles existing LDAP entries without throwing error code 68 (`ldap_add: Already exists`).
- Prevents duplicate mailbox restoration passes.

### 4. Modern Table Formatting & Size Sorting
- Uniform 96-column Unicode rounded box tables for both session lists and session detail views.
- Color-coded backup types (Blue for Full, Cyan for Inc, Purple for Distlist, Magenta for Alias).
- Fast sorting by backup archive size descending with `-S` (`cmbkp -l -S` and `cmbkp -l <session> -S`).

### 5. Verification, Dry-Run & Testing
- **Mailbox Message Auditing (`--verify` / `-c`)**: Compare live mailbox folder message counts (`zmmailbox gaf`) before and after operations.
- **Dry-Run Simulation (`--dry-run`)**: Preview affected accounts and estimated message counts without modifying disk state.
- **Demo Dataset Generator (`cmbkp-demo`)**: Test the TUI, fuzzy search, and table formatting safely in `/tmp/cmbkp_demo` without touching production data.

### 6. Modernized Installer & Backward Compatibility
- Support for Ubuntu 22.04, Ubuntu 24.04 LTS, Debian, RHEL / Rocky / AlmaLinux 8–9.
- Unattended 1-line installation with `./install.sh -y`.
- 100% backward-compatible: `cmbackup` is preserved as a symlink and alias (`/usr/local/bin/cmbackup -> cmbkp`).

---

## Upgrade Instructions

```bash
git clone https://github.com/kit400/cmbkp.git /tmp/cmbkp
cd /tmp/cmbkp
./install.sh -y
```

Verify version:
```bash
cmbkp -v
# Output: cmbkp version: 1.3.0 (alias: cmbackup)
```
