#!/bin/bash
################################################################################
# CMBKP DEMO DATASET GENERATOR
# Generates a realistic mock dataset in domain cmbkp.com for TUI testing & screenshots
################################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_DIR="/tmp/cmbkp_demo"
if id -u zextras &>/dev/null; then
  BACKUP_USER="zextras"
else
  BACKUP_USER="$(whoami)"
fi
SESSION_TYPE="TXT"
LAUNCH_TUI=false
INSTALL_SYSTEM=false

function show_help() {
  cat << EOF
Usage: $(basename "$0") [options]

Generates a realistic test dataset in domain cmbkp.com for testing TUI and capturing screenshots.

Accounts included:
  • Glory.to.Ukraine@cmbkp.com  (777M)
  • ptn.hlo@cmbkp.com           (666M)
  • la-la-la@cmbkp.com          (69M)
  • ptn.hloo@cmbkp.com          (666K)
  • la-la-la-la@cmbkp.com       (69K)

Options:
  -d, --dir <PATH>            Target directory for demo environment (default: /tmp/cmbkp_demo)
  -u, --user <USER>           Backup user to configure (default: current user '$BACKUP_USER')
  --session-type <TYPE>       Session format: TXT or SQLITE3 (default: TXT)
  -s, --system                Also copy demo sessions into live /opt/zextras/backup
  -t, --tui                   Launch TUI immediately after creating dataset
  -h, --help                  Show this help message

Examples:
  $(basename "$0")                     # Create demo dataset in /tmp/cmbkp_demo
  $(basename "$0") --tui               # Create dataset and launch TUI immediately
  $(basename "$0") --system            # Create dataset and link to /opt/zextras/backup
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dir)
      TARGET_DIR="$2"
      shift 2
      ;;
    -u|--user)
      BACKUP_USER="$2"
      shift 2
      ;;
    --session-type)
      SESSION_TYPE="$2"
      shift 2
      ;;
    -s|--system)
      INSTALL_SYSTEM=true
      shift
      ;;
    -t|--tui)
      LAUNCH_TUI=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

echo "=================================================================="
echo " Creating CMBKP Demo Dataset in domain: cmbkp.com"
echo " Target Directory: $TARGET_DIR"
echo "=================================================================="

WORKDIR="$TARGET_DIR/backup"
mkdir -p "$WORKDIR"

# 1. Accounts list file
ACCOUNTS_FILE="$TARGET_DIR/accounts.txt"
cat << 'EOF' > "$ACCOUNTS_FILE"
Glory.to.Ukraine@cmbkp.com
ptn.hlo@cmbkp.com
la-la-la@cmbkp.com
ptn.hloo@cmbkp.com
la-la-la-la@cmbkp.com
EOF

# 2. Mock live mailbox storage (gqu.txt format: account quota used_bytes)
GQU_FILE="$TARGET_DIR/gqu.txt"
cat << 'EOF' > "$GQU_FILE"
Glory.to.Ukraine@cmbkp.com 1073741824 814743552
ptn.hlo@cmbkp.com 1073741824 698351616
la-la-la@cmbkp.com 1073741824 72351744
ptn.hloo@cmbkp.com 1073741824 681984
la-la-la-la@cmbkp.com 1073741824 70656
EOF

# Copy gqu.txt to /tmp/gqu.txt as well for default TUI preview discovery
cp -f "$GQU_FILE" /tmp/gqu.txt 2>/dev/null || true

# 3. Create Demo Sessions
SESS_FULL="full-20261001120000"
SESS_INC="inc-20261001123000"
SESS_DL="distlist-20261001121500"

rm -rf "$WORKDIR/$SESS_FULL" "$WORKDIR/$SESS_INC" "$WORKDIR/$SESS_DL"
mkdir -p "$WORKDIR/$SESS_FULL" "$WORKDIR/$SESS_INC" "$WORKDIR/$SESS_DL"

# Populate full session files with exact declared sizes (sparse files take 0 actual disk space)
truncate -s 777M "$WORKDIR/$SESS_FULL/Glory.to.Ukraine@cmbkp.com.tgz"
truncate -s 0    "$WORKDIR/$SESS_FULL/Glory.to.Ukraine@cmbkp.com.ldiff"

truncate -s 666M "$WORKDIR/$SESS_FULL/ptn.hlo@cmbkp.com.tgz"
truncate -s 0    "$WORKDIR/$SESS_FULL/ptn.hlo@cmbkp.com.ldiff"

truncate -s 69M  "$WORKDIR/$SESS_FULL/la-la-la@cmbkp.com.tgz"
truncate -s 0    "$WORKDIR/$SESS_FULL/la-la-la@cmbkp.com.ldiff"

truncate -s 666K "$WORKDIR/$SESS_FULL/ptn.hloo@cmbkp.com.tgz"
truncate -s 0    "$WORKDIR/$SESS_FULL/ptn.hloo@cmbkp.com.ldiff"

truncate -s 69K  "$WORKDIR/$SESS_FULL/la-la-la-la@cmbkp.com.tgz"
truncate -s 0    "$WORKDIR/$SESS_FULL/la-la-la-la@cmbkp.com.ldiff"

# Populate inc session files
truncate -s 124M "$WORKDIR/$SESS_INC/Glory.to.Ukraine@cmbkp.com.tgz"
truncate -s 0    "$WORKDIR/$SESS_INC/Glory.to.Ukraine@cmbkp.com.ldiff"

truncate -s 88M  "$WORKDIR/$SESS_INC/ptn.hlo@cmbkp.com.tgz"
truncate -s 0    "$WORKDIR/$SESS_INC/ptn.hlo@cmbkp.com.ldiff"

truncate -s 12M  "$WORKDIR/$SESS_INC/la-la-la@cmbkp.com.tgz"
truncate -s 0    "$WORKDIR/$SESS_INC/la-la-la@cmbkp.com.ldiff"

truncate -s 42K  "$WORKDIR/$SESS_INC/ptn.hloo@cmbkp.com.tgz"
truncate -s 0    "$WORKDIR/$SESS_INC/ptn.hloo@cmbkp.com.ldiff"

# Distribution list session
truncate -s 8K   "$WORKDIR/$SESS_DL/all.heroes@cmbkp.com.ldiff"

# 4. Create sessions.txt
SESSIONS_TXT="$WORKDIR/sessions.txt"
cat << EOF > "$SESSIONS_TXT"
SESSION: $SESS_FULL started at Thu Oct  1 12:00:00 EEST 2026
$SESS_FULL:Glory.to.Ukraine@cmbkp.com:2026-10-01
$SESS_FULL:ptn.hlo@cmbkp.com:2026-10-01
$SESS_FULL:la-la-la@cmbkp.com:2026-10-01
$SESS_FULL:ptn.hloo@cmbkp.com:2026-10-01
$SESS_FULL:la-la-la-la@cmbkp.com:2026-10-01
SESSION: $SESS_FULL completed at Thu Oct  1 12:05:00 EEST 2026
SESSION: $SESS_DL started at Thu Oct  1 12:15:00 EEST 2026
$SESS_DL:all.heroes@cmbkp.com:2026-10-01
SESSION: $SESS_DL completed at Thu Oct  1 12:15:05 EEST 2026
SESSION: $SESS_INC started at Thu Oct  1 12:30:00 EEST 2026
$SESS_INC:Glory.to.Ukraine@cmbkp.com:2026-10-01
$SESS_INC:ptn.hlo@cmbkp.com:2026-10-01
$SESS_INC:la-la-la@cmbkp.com:2026-10-01
$SESS_INC:ptn.hloo@cmbkp.com:2026-10-01
SESSION: $SESS_INC completed at Thu Oct  1 12:32:00 EEST 2026
EOF

# 5. Create sessions.sqlite3
SQLITE_DB="$WORKDIR/sessions.sqlite3"
rm -f "$SQLITE_DB"

function execute_sql() {
  local db_path="$1"
  local sql_code="$2"
  if command -v sqlite3 &>/dev/null; then
    sqlite3 "$db_path" <<< "$sql_code"
  elif command -v python3 &>/dev/null; then
    python3 -c "
import sqlite3, sys
conn = sqlite3.connect('$db_path')
conn.executescript(sys.stdin.read())
conn.commit()
conn.close()
" <<< "$sql_code"
  else
    echo "Warning: Neither sqlite3 CLI nor python3 found, skipping SQLite database creation."
  fi
}

SCHEMA_SQL="
create table if not exists backup_session(
  sessionID varchar primary key,
  initial_date timestamp not null,
  conclusion_date timestamp,
  size varchar,
  type varchar not null,
  status varchar not null
);

create table if not exists backup_account(
  id integer primary key autoincrement,
  sessionID varchar not null,
  account_size varchar not null,
  email varchar not null,
  initial_date timestamp not null,
  conclusion_date timestamp,
  foreign key (sessionID) references backup_session(sessionID)
);
"
execute_sql "$SQLITE_DB" "$SCHEMA_SQL"

DATA_SQL="
INSERT INTO backup_session VALUES ('$SESS_FULL', '2026-10-01 12:00:00', '2026-10-01 12:05:00', '1.5G', 'Full Backup', 'FINISHED');
INSERT INTO backup_session VALUES ('$SESS_DL', '2026-10-01 12:15:00', '2026-10-01 12:15:05', '8.0K', 'Distribution List', 'FINISHED');
INSERT INTO backup_session VALUES ('$SESS_INC', '2026-10-01 12:30:00', '2026-10-01 12:32:00', '224M', 'Incremental Backup', 'FINISHED');

INSERT INTO backup_account VALUES (NULL, '$SESS_FULL', '777M', 'Glory.to.Ukraine@cmbkp.com', '2026-10-01 12:00:00', '2026-10-01 12:01:00');
INSERT INTO backup_account VALUES (NULL, '$SESS_FULL', '666M', 'ptn.hlo@cmbkp.com', '2026-10-01 12:01:00', '2026-10-01 12:02:00');
INSERT INTO backup_account VALUES (NULL, '$SESS_FULL', '69M',  'la-la-la@cmbkp.com', '2026-10-01 12:02:00', '2026-10-01 12:03:00');
INSERT INTO backup_account VALUES (NULL, '$SESS_FULL', '666K', 'ptn.hloo@cmbkp.com', '2026-10-01 12:03:00', '2026-10-01 12:04:00');
INSERT INTO backup_account VALUES (NULL, '$SESS_FULL', '69K',  'la-la-la-la@cmbkp.com', '2026-10-01 12:04:00', '2026-10-01 12:05:00');

INSERT INTO backup_account VALUES (NULL, '$SESS_INC', '124M', 'Glory.to.Ukraine@cmbkp.com', '2026-10-01 12:30:00', '2026-10-01 12:30:45');
INSERT INTO backup_account VALUES (NULL, '$SESS_INC', '88M',  'ptn.hlo@cmbkp.com', '2026-10-01 12:30:45', '2026-10-01 12:31:20');
INSERT INTO backup_account VALUES (NULL, '$SESS_INC', '12M',  'la-la-la@cmbkp.com', '2026-10-01 12:31:20', '2026-10-01 12:31:45');
INSERT INTO backup_account VALUES (NULL, '$SESS_INC', '42K',  'ptn.hloo@cmbkp.com', '2026-10-01 12:31:45', '2026-10-01 12:32:00');
"
execute_sql "$SQLITE_DB" "$DATA_SQL"

# 6. Generate cmbkp.conf for this demo environment
CONF_FILE="$TARGET_DIR/cmbkp.conf"
cat << EOF > "$CONF_FILE"
BACKUPUSER="${BACKUP_USER:-\$(whoami)}"
WORKDIR="$WORKDIR"
SESSION_TYPE="$SESSION_TYPE"
ROTATE_TIME="30"
LOCK_BACKUP=false
MAX_PARALLEL_PROCESS=3
MIN_FREE_DISK_GB=1
BACKUP_INACTIVE_ACCOUNTS=true
SSL_ENABLE=true
CMBKP_ACCOUNTS_FILE="$ACCOUNTS_FILE"
CMBKP_GQU_FILE="$GQU_FILE"
EOF

# 7. Helper runner script
RUN_SCRIPT="$TARGET_DIR/run_demo_tui.sh"
cat << 'EOF' > "$RUN_SCRIPT"
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="$SCRIPT_DIR/cmbkp.conf"
ACCOUNTS_FILE="$SCRIPT_DIR/accounts.txt"
GQU_FILE="$SCRIPT_DIR/gqu.txt"

export CMBKP_CONF="$CONF_FILE"
export CMBKP_ACCOUNTS_FILE="$ACCOUNTS_FILE"
export CMBKP_GQU_FILE="$GQU_FILE"

CMBKP_BIN="$(command -v cmbkp 2>/dev/null || true)"
if [ -z "$CMBKP_BIN" ]; then
  # Fallback to repository binary if not in system PATH
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"
  if [ -f "$REPO_ROOT/project/cmbkp" ]; then
    CMBKP_BIN="$REPO_ROOT/project/cmbkp"
  elif [ -f "$HOME/kit400/cmbkp/project/cmbkp" ]; then
    CMBKP_BIN="$HOME/kit400/cmbkp/project/cmbkp"
  fi
fi

if [ -z "$CMBKP_BIN" ] || [ ! -x "$CMBKP_BIN" ]; then
  echo "Error: cmbkp binary not found in PATH or repo. Run with full path: /path/to/cmbkp --config $CONF_FILE --tui"
  exit 1
fi

exec "$CMBKP_BIN" --config "$CONF_FILE" --tui
EOF
chmod +x "$RUN_SCRIPT"

# 8. Optional: install into live system if requested
if [ "$INSTALL_SYSTEM" = true ]; then
  SYS_BKP="/opt/zextras/backup"
  if [ -d "$SYS_BKP" ]; then
    echo "Registering demo sessions into system backup directory: $SYS_BKP..."
    cp -rn "$WORKDIR/$SESS_FULL" "$WORKDIR/$SESS_INC" "$WORKDIR/$SESS_DL" "$SYS_BKP/" 2>/dev/null || true
    cat "$SESSIONS_TXT" >> "$SYS_BKP/sessions.txt" 2>/dev/null || true
    if [ -f "$SYS_BKP/sessions.sqlite3" ]; then
      sqlite3 "$SYS_BKP/sessions.sqlite3" << EOF
INSERT OR IGNORE INTO backup_session VALUES ('$SESS_FULL', '2026-10-01 12:00:00', '2026-10-01 12:05:00', '1.5G', 'Full Backup', 'FINISHED');
INSERT OR IGNORE INTO backup_session VALUES ('$SESS_DL', '2026-10-01 12:15:00', '2026-10-01 12:15:05', '8.0K', 'Distribution List', 'FINISHED');
INSERT OR IGNORE INTO backup_session VALUES ('$SESS_INC', '2026-10-01 12:30:00', '2026-10-01 12:32:00', '224M', 'Incremental Backup', 'FINISHED');

INSERT INTO backup_account VALUES (NULL, '$SESS_FULL', '777M', 'Glory.to.Ukraine@cmbkp.com', '2026-10-01 12:00:00', '2026-10-01 12:01:00');
INSERT INTO backup_account VALUES (NULL, '$SESS_FULL', '666M', 'ptn.hlo@cmbkp.com', '2026-10-01 12:01:00', '2026-10-01 12:02:00');
INSERT INTO backup_account VALUES (NULL, '$SESS_FULL', '69M',  'la-la-la@cmbkp.com', '2026-10-01 12:02:00', '2026-10-01 12:03:00');
INSERT INTO backup_account VALUES (NULL, '$SESS_FULL', '666K', 'ptn.hloo@cmbkp.com', '2026-10-01 12:03:00', '2026-10-01 12:04:00');
INSERT INTO backup_account VALUES (NULL, '$SESS_FULL', '69K',  'la-la-la-la@cmbkp.com', '2026-10-01 12:04:00', '2026-10-01 12:05:00');

INSERT INTO backup_account VALUES (NULL, '$SESS_INC', '124M', 'Glory.to.Ukraine@cmbkp.com', '2026-10-01 12:30:00', '2026-10-01 12:30:45');
INSERT INTO backup_account VALUES (NULL, '$SESS_INC', '88M',  'ptn.hlo@cmbkp.com', '2026-10-01 12:30:45', '2026-10-01 12:31:20');
INSERT INTO backup_account VALUES (NULL, '$SESS_INC', '12M',  'la-la-la@cmbkp.com', '2026-10-01 12:31:20', '2026-10-01 12:31:45');
INSERT INTO backup_account VALUES (NULL, '$SESS_INC', '42K',  'ptn.hloo@cmbkp.com', '2026-10-01 12:31:45', '2026-10-01 12:32:00');
EOF
    fi
    chown -R zextras:zextras "$SYS_BKP" 2>/dev/null || true
  fi
fi

if [ "$(id -u)" -eq 0 ] && id -u "$BACKUP_USER" &>/dev/null; then
  chown -R "$BACKUP_USER":"$BACKUP_USER" "$TARGET_DIR" 2>/dev/null || true
fi
chmod -R a+rwX "$TARGET_DIR" 2>/dev/null || true

echo ""
echo "Demo dataset successfully generated at: $TARGET_DIR"
echo ""
echo "Accounts created:"
cat "$ACCOUNTS_FILE" | while read -r acc; do
  echo "  ● $acc"
done
echo ""
echo "To run interactive TUI with this demo dataset:"
echo "  $RUN_SCRIPT"
echo ""
echo "Or using cmbkp CLI directly:"
echo "  cmbkp --config $CONF_FILE --tui"
echo "  cmbkp --config $CONF_FILE -l -S"
echo "  cmbkp --config $CONF_FILE -l $SESS_FULL -S"
echo ""

if [ "$LAUNCH_TUI" = true ]; then
  exec "$RUN_SCRIPT"
fi
