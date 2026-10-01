# 🚀 Announcing cmbkp 1.3.0: Modern Hot Backup & Disaster Recovery Suite for Carbonio Community Edition (CE)

Hello Carbonio Community!

I am excited to share **cmbkp** (formerly `cmbackup`), an enhanced, modernized, and production-tested hot backup and disaster recovery suite designed specifically for **Zextras Carbonio Community Edition (CE)**.

* **GitHub Repository**: https://github.com/kit400/cmbkp
* **License**: GNU General Public License v2 (Open Source)
* **Compatibility**: Carbonio CE 23.x – 26.x (Ubuntu 22.04 / 24.04 LTS, Debian, RHEL / Rocky / AlmaLinux 8–9)

---

### Why cmbkp?

While the classic `zmbackup` and `cmbackup` tools provided a solid foundation for bash-based mailbox dumps, real-world production environments frequently run into critical bottlenecks:
* **No interactive discovery**: Restoring an account required memorizing exact timestamps and session names.
* **Risk of disk space exhaustion**: Running a backup job blind could fill the disk partition and crash Carbonio databases/services.
* **Inefficient queueing**: Parallel multi-core backups queued accounts arbitrarily, leaving massive mailboxes running at the very end of the backup window.
* **Restoration friction**: Duplicate account handling caused LDAP collisions (`ldap_add: Already exists (68)`).

**cmbkp 1.3.0** addresses these issues by integrating battle-tested architectural innovations from **Z2C (Zimbra to Carbonio Migration Suite)** alongside a brand-new, keyboard-driven **`fzf` interactive TUI**.

---

### 🌟 Key Features & What's New

#### 1. Interactive Terminal UI (`fzf`-Powered)
Launch with `cmbkp --tui` (or `cmbkp -ui`):
* **Fuzzy Account Search**: Type any part of an email address to filter through thousands of accounts instantly.
* **Side-by-Side Live Preview Pane**: Inspect live mailbox quota usage, available backup restore points, and recent archives on disk in real time.
* **Batch Multi-Select**: Press <kbd>Tab</kbd> to select multiple accounts and launch batch backups.
* **Guided Restore Wizard**: Select an account, choose from its available backup sessions, select destination (original or alternate account with `-ro`), and confirm safely.
* **Session Explorer**: Browse past backup sessions with contained mailbox previews and jump directly into formatted details tables.

#### 2. LPT (Longest Processing Time First) Scheduling (from Z2C)
* Rather than processing accounts alphabetically or randomly, `cmbkp` queries mailbox storage quotas (`zmprov gqu`) and sorts accounts descending before passing them to GNU Parallel.
* Largest mailboxes start processing immediately across all available CPU cores, eliminating queue tail bottlenecks and completing backup windows **up to 3x faster**.

#### 3. Pre-Flight Disk Space Safeguards (from Z2C)
* Automatically checks free disk space against a configurable threshold (`MIN_FREE_DISK_GB=5`) before executing dumps.
* Prevents disk space exhaustion from taking down Carbonio mailboxd or LDAP services.

#### 4. Clean Incremental Dumps & HTTP 204 Handling
* Detects Carbonio REST HTTP `204 No Data` responses when accounts have no new messages.
* Skips empty dumps and automatically purges 0-byte `.tgz` files to keep storage clean.

#### 5. Safe & Clean Account Restores
* Enhanced restore logic cleanly detects if an account already exists in LDAP, gracefully proceeding to mailbox data restore without throwing error code 68.
* Prevents duplicate mailbox restoration passes.

#### 6. Consistent 96-Column Tables with Size Sorting
* Uniform Unicode rounded box tables for both session lists (`cmbkp -l`) and session details (`cmbkp -l <session>`).
* Color-coded backup types (Blue for Full, Cyan for Inc, Purple for Distlist).
* Sort sessions and account tables by archive size descending with `-S` (`cmbkp -l -S`).

#### 7. Verification & Dry-Run Modes
* **Message Auditing (`-c` / `--verify`)**: Compare message counts per folder (`zmmailbox gaf`) before and after operations.
* **Dry-Run Mode (`--dry-run`)**: Preview affected accounts and estimated message counts without modifying disk state.

#### 8. Built-in Demo Dataset Generator (`cmbkp-demo`)
* Comes with a mock dataset generator (`cmbkp-demo`) to test the TUI, fuzzy search, and table formatting safely in `/tmp/cmbkp_demo` without touching production data.

---

### 🔄 100% Backward Compatible

`cmbackup` is fully preserved as a symlink and alias (`/usr/local/bin/cmbackup -> cmbkp`). Existing cron jobs, automation scripts, and habits continue to work with zero breaking changes.

---

### 📦 Quick Start & Installation

Run as `root` on your Carbonio server:

```bash
git clone https://github.com/kit400/cmbkp.git /tmp/cmbkp
cd /tmp/cmbkp
./install.sh -y
```

Launch the interactive console:
```bash
su - zextras -c "cmbkp --tui"
```

List sessions sorted by size:
```bash
su - zextras -c "cmbkp -l -S"
```

---

Feedback, bug reports, and pull requests are warmly welcome on [GitHub](https://github.com/kit400/cmbkp)!
