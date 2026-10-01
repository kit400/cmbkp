# Upgrade Guide: Upgrading from cmbackup to cmbkp (v1.3.0)

This guide provides step-by-step instructions for upgrading existing **cmbackup** (or legacy **zmbackup**) installations to **cmbkp 1.3.0** on Zextras Carbonio Community Edition (CE).

---

## 1. Overview & Backward Compatibility

**cmbkp** is a drop-in replacement for `cmbackup`. It is designed with **100% backward compatibility**:
* **Preserved Command & Symlink**: `/usr/local/bin/cmbackup` is automatically symlinked to `/usr/local/bin/cmbkp`. All existing cron jobs, wrapper scripts, and CLI invocations using `cmbackup` continue to run without modification.
* **Preserved Configuration**: Existing configurations in `/etc/cmbackup/cmbackup.conf` are preserved and symlinked to `/etc/cmbkp/cmbkp.conf`.
* **Preserved Backup Sessions**: Existing backup archives, `sessions.txt`, and `sessions.sqlite3` in `/opt/zextras/backup` are recognized immediately without requiring database migrations.
* **Shell Alias**: A system-wide profile alias (`alias cmbackup='cmbkp'`) is installed in `/etc/profile.d/cmbkp.sh`.

---

## 2. Why Upgrade to cmbkp 1.3.0?

| Feature | Legacy cmbackup | cmbkp 1.3.0 |
|:---|:---:|:---:|
| **Interactive Management (TUI)** | ❌ None (CLI only) | ✅ **`fzf`-powered interactive console (`cmbkp --tui`)** |
| **Account Discovery & Preview** | ❌ Must remember email syntax | ✅ **Fuzzy-search with live quota & session preview** |
| **Parallel Backup Scheduling** | ⚠️ Alphabetical / Random | ✅ **LPT (Longest Processing Time First) up to 3x faster** |
| **Disk Space Safeguard** | ❌ Writes blind until disk is full | ✅ **Pre-flight check (`MIN_FREE_DISK_GB=5`) prevents crashes** |
| **Incremental Clean Dumps** | ❌ Clutters storage with 0-byte dumps | ✅ **HTTP 204 No Data handling cleans empty archives** |
| **Safe Account Restore** | ⚠️ Collides on existing LDAP entries (68) | ✅ **Detects existing accounts & restores cleanly** |
| **CLI Output & Tables** | ⚠️ Uneven ASCII `+---+` tables | ✅ **Uniform 96-column Unicode rounded boxes & subtle colors** |
| **Size-Based Sorting** | ❌ Chronological only | ✅ **Fast archive size sorting (`-S` / `--sort-size`)** |
| **Mailbox Message Auditing** | ❌ None | ✅ **`zmmailbox gaf` folder verification (`--verify` / `-c`)** |
| **OS Compatibility** | ⚠️ Older Ubuntu/RHEL | ✅ **Ubuntu 22.04, Ubuntu 24.04 LTS, Debian, RHEL 8–9** |

---

## 3. Preparation & Pre-Upgrade Checks

Before upgrading, verify your current installation as `root`:

```bash
# 1. Check current cmbackup version
su - zextras -c "cmbackup -v"

# 2. Check that Carbonio services are running
su - zextras -c "zmcontrol status"

# 3. (Optional) Create a safety backup of your current configuration
cp -a /etc/cmbackup /etc/cmbackup.bak.$(date +%F)
```

---

## 4. Upgrade Instructions

### Method A: Automated In-Place Upgrade (Recommended)

Run as `root` on your Carbonio server:

```bash
# Clone the latest cmbkp repository
git clone https://github.com/kit400/cmbkp.git /tmp/cmbkp
cd /tmp/cmbkp

# Run the installer in unattended mode
./install.sh -y
```

The installer will:
1. Detect your existing `cmbackup` installation.
2. Install required dependencies (`fzf`, `parallel`, `sqlite3`).
3. Deploy the updated `cmbkp` binary and modular libraries.
4. Establish compatibility symlinks (`cmbackup -> cmbkp`, `/etc/cmbackup <-> /etc/cmbkp`).
5. Preserve your existing `cmbackup.conf` settings intact.

---

### Method B: Interactive Upgrade

If you prefer to review steps interactively:

```bash
cd /tmp/cmbkp
./install.sh
```

Follow the on-screen prompts. The installer will confirm upgrade detection and apply all enhancements.

---

## 5. Post-Upgrade Verification

Verify that both `cmbkp` and the `cmbackup` alias report the new version:

```bash
# Test cmbkp binary
su - zextras -c "cmbkp -v"
# Output: cmbkp version: 1.3.0 (alias: cmbackup)

# Test cmbackup compatibility alias
su - zextras -c "cmbackup -v"
# Output: cmbkp version: 1.3.0 (alias: cmbackup)
```

Inspect past backup sessions with the new 96-column box drawing tables:

```bash
# List all sessions sorted by size
su - zextras -c "cmbkp -l -S"

# Inspect a specific past session
su - zextras -c "cmbkp -l <SESSION_NAME> -S"
```

Launch the new interactive TUI:

```bash
su - zextras -c "cmbkp --tui"
```

---

## 6. Recommended Configuration Enhancements

Your existing configuration in `/etc/cmbkp/cmbkp.conf` (symlinked from `/etc/cmbackup/cmbackup.conf`) will continue working as-is. However, you can take advantage of the following new configuration directives:

Edit `/etc/cmbkp/cmbkp.conf`:

```ini
# MIN_FREE_DISK_GB - Minimum free disk space (in GB) required on WORKDIR
#                    before allowing backup or restore routines to execute.
#                    Prevents disk exhaustion from crashing Carbonio services.
#                    DEFAULT: 5
MIN_FREE_DISK_GB=5

# ZMMAILBOX_URL - URL endpoint for zmmailbox REST API requests.
#                 DEFAULT: https://localhost:7071
ZMMAILBOX_URL=https://localhost:7071
```

---

## 7. Cron Jobs & Automation

Existing cron schedules remain fully operational.

If you have `/etc/cron.d/cmbackup`, it will invoke `cmbackup`, which now transparently runs `cmbkp` with all performance optimizations enabled.

To standardize your cron file to the new naming convention (optional):

```bash
mv /etc/cron.d/cmbackup /etc/cron.d/cmbkp 2>/dev/null || true
```

---

## 8. Rollback Procedure

If you ever need to revert to your previous installation:

```bash
# 1. Restore previous configuration backup if changed
[ -d /etc/cmbackup.bak.* ] && cp -a /etc/cmbackup.bak.* /etc/cmbackup

# 2. Reinstall previous version from your backup source or repository checkout
cd /path/to/old/cmbackup
./install.sh -y
```

---

## 9. Troubleshooting & FAQ

#### Q: Do I need to update my cron jobs or existing shell scripts?
**No.** `cmbackup` is maintained as a symlink and shell alias to `cmbkp`. All existing commands like `cmbackup -f`, `cmbackup -i`, and `cmbackup -hp` continue to work without modification.

#### Q: Will my previous backups remain accessible?
**Yes.** All past backup directories and `sessions.txt` / `sessions.sqlite3` records in `/opt/zextras/backup` are 100% compatible and will display immediately in `cmbkp -l` and the TUI session explorer.

#### Q: What happened to `zmbhousekeep`?
The legacy standalone script `zmbhousekeep` has been replaced by `cmbkp -hp` (`--housekeep`), which performs automated retention cleanup according to `ROTATE_TIME`.

#### Q: How do I test the new TUI safely without touching production data?
Run the built-in demo environment generator:
```bash
cmbkp-demo
# Then launch the demo TUI:
cmbkp --config /tmp/cmbkp_demo/cmbkp.conf --tui
```
