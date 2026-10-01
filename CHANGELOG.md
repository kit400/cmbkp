# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.3.1] - 2026-10-01

### Fixed
- **Domain Restore Filtering**: Resolved an issue in `build_listRST()` where passing `-d domain.com` or `domain.com` was ignored because the filter only checked for `@`, causing the entire session to be restored. Now accurately filters accounts matching `@domain.com`.
- **Argument Forwarding in RestoreAction**: Fixed parameter forwarding in `restore_main_mailbox()` and `restore_main_ldap()` so domain arguments are properly delivered to `build_listRST()`.
- **Installer Upgrade Detection**: Enhanced `installScript/check.sh` to automatically detect older `cmbackup` versions and initiate in-place upgrades without requiring explicit `--force-upgrade` flags.
- **Config & Symlink Preservation**: Hardened `installScript/deploy.sh` to seamlessly preserve existing `/etc/cmbackup/cmbackup.conf` settings and establish bidirectional symlinks during upgrades.

### Added
- **Bugfixes Reference**: Added [`docs/BUGFIXES.md`](docs/BUGFIXES.md) detailing root causes and solutions for all historical issues.
- **Upgrade Guide**: Added [`docs/UPGRADE.md`](docs/UPGRADE.md) providing step-by-step in-place migration instructions.

---

## [1.3.0] - 2026-10-01

### Added
- **Interactive TUI with `fzf` Search (`--tui` / `-ui`)**:
  - Full-screen fuzzy-finder for instant account and session discovery.
  - Side-by-side preview panel showing live mailbox storage, past backup history, and physical archives.
  - Batch multi-select with <kbd>Tab</kbd> for multi-account backups.
  - Guided interactive restore wizard with alternate account (`-ro`) support.
- **LPT (Longest Processing Time First) Scheduling (from Z2C)**:
  - Dynamically sorts accounts descending by quota (`zmprov gqu`) before queuing in GNU Parallel.
  - Completes multi-core backup runs up to 3x faster by eliminating tail bottlenecks.
- **Pre-Flight Disk Space Safeguards (from Z2C)**:
  - Enforces `MIN_FREE_DISK_GB=5` threshold before running backups or restores to prevent crashing Carbonio databases.
- **HTTP 204 Clean Incremental Dumps (from Z2C)**:
  - Skips empty dumps when Carbonio REST reports no changes, keeping backup storage clean.
- **Uniform 96-Column Tables & ANSI Colors**:
  - Replaced legacy ASCII tables with standardized Unicode rounded boxes (`╭───┬───╮`).
  - Date column positioned before Size with matching 12-char column widths.
  - Color-coded backup types (Blue for Full, Cyan for Inc, Purple for Distlist).
- **Fast Size-Based Sorting (`-S` / `--sort-size`)**:
  - Sort sessions and account tables by backup archive size descending.
- **Mailbox Message Auditing (`--verify` / `-c`)**:
  - Compare message counts per folder (`zmmailbox gaf`) before and after backups.
- **Dry-Run Mode (`--dry-run`)**:
  - Preview affected accounts and message estimates without altering disk state.
- **Demo Dataset Generator (`cmbkp-demo`)**:
  - Self-contained test dataset in `/tmp/cmbkp_demo` for safe TUI testing and documentation screenshots.
- **Backward Compatibility**:
  - Maintained `cmbackup` as a symlink and shell alias (`/usr/local/bin/cmbackup -> cmbkp`).

### Fixed
- **Safe Account Restore**:
  - Gracefully handles existing LDAP entries without throwing error code 68 (`ldap_add: Already exists`).
  - Fixed duplicate mailbox restoration loops during full/incremental session restores.
- **REST URL Configuration**:
  - Added configurable `ZMMAILBOX_URL` to support non-standard admin endpoints and SSL proxies.
- **SQLite Concurrency**:
  - Added `cmbkp_sqlite` with Python 3 fallback to eliminate `database is locked` race conditions.

---

## [1.2.0] - 2024-11-08

### Fixed
- PR #1 by Marco Steinacher:
  - Fixed string substitution typo (`${4//s/\n/g}`) that corrupted domains/accounts containing the letter `s`.
  - Fixed command substitution syntax error in `BackupAction.sh`.
  - Introduced `ZMMAILBOX_URL` configuration directive.
  - Fixed race condition in SQLite existing backup checks.

---

## [1.0.0] - 2024-04-01

### Added
- Initial fork and adaptation of `zmbackup` for Zextras Carbonio Community Edition (CE) by Anahuac Gil.
