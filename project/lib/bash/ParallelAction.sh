#!/bin/bash
################################################################################
# Repeatable Actions
################################################################################

###############################################################################
# ldap_backup: Backup a LDAP object inside a file.
# Options:
# $1 - The object's mail account that should be backed up;
# $2 - The type of object should be backed up. Valid values:
#     DLOBJECT - Distribution List;
#     ACOBJECT - User Account;
#     ALOBJECT - Alias;
#     SIOBJECT - Signature.
###############################################################################
function ldap_backup()
{
  TEMP_CLI_OUTPUT=$(mktemp)
  ldapsearch -Z -x -H "$LDAPSERVER" -D "$LDAPADMIN" -w "$LDAPPASS" -b '' \
             -LLL "(&(|(mail=$1)(uid=$1))$2)" > "$TEMPDIR"/"$1".ldiff 2> "$TEMP_CLI_OUTPUT"
  BASHERRCODE=$?
  if [[ $BASHERRCODE -eq 0 ]]; then
    logger -i -p local7.info "Cmbackup: LDAP - Backup for account $1 finished."
    export ERRCODE=0
  else
    logger -i -p local7.err "Cmbackup: LDAP - Backup for account $1 failed. Error message below:"
    echo "Cmbackup: $1 " | logger -i -p local7.err
    logger -i -p local7.err  < "$TEMP_CLI_OUTPUT"
    export ERRCODE=1
  fi
  rm -rf "${TEMP_CLI_OUTPUT:?}"
}


###############################################################################
# mailbox_backup: Backup user's mailbox in TGZ format.
# Options:
# $1 - The user's account to be backed up;
###############################################################################
function mailbox_backup()
{
  TEMP_CLI_OUTPUT=$(mktemp)
  check_disk_space "$TEMPDIR" "$MIN_FREE_DISK_GB"

  AFTER=""
  if [[ "$INC" == "TRUE" ]]; then
    if [[ -n "$SINCE_DATE" ]]; then
      DATE="$SINCE_DATE"
    elif [[ $SESSION_TYPE == 'TXT' ]]; then
      DATE=$(grep "$1" "$WORKDIR"/sessions.txt 2>/dev/null | tail -1 | awk -F: '{print $3}' | cut -d'-' -f2)
    elif [[ $SESSION_TYPE == 'SQLITE3' ]]; then
      DATE=$(sqlite3 "$WORKDIR"/sessions.sqlite3 "select MAX(initial_date) \
             from backup_account where email='$1' and \
             (sessionID like 'full%' or sessionID like 'inc%' or sessionID like 'mbox%')" 2>/dev/null)
    fi
    if [[ -n "$DATE" ]]; then
      START_TS=$(date -d "$DATE" +%s 2>/dev/null)
      if [[ -n "$START_TS" ]]; then
        AFTER='&'"start=${START_TS}000"
      fi
    fi
  fi

  if [[ "$DRY_RUN" == "TRUE" ]]; then
    logger -i -p local7.info "Cmbackup: [DRY-RUN] Mailbox check for account $1"
    echo "[DRY-RUN] Account $1 - backup simulated (no data transferred)."
    export ERRCODE=0
    rm -rf "${TEMP_CLI_OUTPUT:?}"
    return 0
  fi

  $ZMMAILBOX -t 0 -z -m "$1" getRestURL -u "$ZMMAILBOX_URL" --output "$TEMPDIR"/"$1".tgz "/?fmt=tgz&resolve=skip$AFTER" > "$TEMP_CLI_OUTPUT" 2>&1
  BASHERRCODE=$?
  CLI_OUT=$(cat "$TEMP_CLI_OUTPUT")

  if [[ $BASHERRCODE -eq 0 ]]; then
    if [[ -s $TEMPDIR/$1.tgz ]]; then
      logger -i -p local7.info "Cmbackup: Mailbox - Backup for account $1 finished."
    else
      # HTTP 204 or empty archive detection (from z2c)
      logger -i -p local7.info "Cmbackup: Mailbox - No changes for account $1 (empty dump/204 No Data). Removing temporary empty file."
      rm -rf "$TEMPDIR"/"$1".tgz
    fi
    export ERRCODE=0
  else
    if [[ "$CLI_OUT" == *"status=204"* ]]; then
      logger -i -p local7.info "Cmbackup: Mailbox - Account $1 has no new data since last sync (204 No Data)."
      rm -rf "$TEMPDIR"/"$1".tgz
      export ERRCODE=0
    else
      logger -i -p local7.err "Cmbackup: Mailbox - Backup for account $1 failed. Error message below:"
      echo "Cmbackup: $1 " | logger -i -p local7.err
      logger -i -p local7.err < "$TEMP_CLI_OUTPUT"
      export ERRCODE=1
    fi
  fi
  rm -rf "${TEMP_CLI_OUTPUT:?}"
}


###############################################################################
# ldap_restore: Restore a LDAP object inside a file.
# Options:
# $1 - The session file to be restored;
# $2 - The account that should be restored.
###############################################################################
function ldap_restore()
{
  printf "\n - Restoring LDAP from %s" "$WORKDIR/$1/$2.ldiff"
  ERR=$( (ldapadd -x -H "$LDAPSERVER" -D "$LDAPADMIN" \
           -c -w "$LDAPPASS" -f "$WORKDIR"/"$1"/"$2".ldiff) 2>&1)
  BASHERRCODE=$?
  if ! [[ $BASHERRCODE -eq 0 ]]; then
    printf "\nError during the restore process for account %s. Error message below:" "$2"
    printf "\n%s: %s" "$2" "$ERR"
  fi
}

###############################################################################
# mailbox_restore: Restore a mailbox from archive.
# Options:
# $1 - The session file to be restored;
# $2 - The account that should be restored.
###############################################################################
function mailbox_restore()
{
  printf "\n - Restoring Mailbox from %s" "$WORKDIR/$1/$2.tgz"
  if ! [[ -f "$WORKDIR/$1/$2.tgz" ]]; then
    printf "\nAccount %s has no archive in session %s - skipping..." "$2" "$1"
    return 0
  fi
  TEMP_CLI_OUTPUT=$(mktemp)
  zmlocalconfig -e socket_so_timeout=99999999
  $ZMMAILBOX -t 0 -z -m "$2" postRestURL -u "$ZMMAILBOX_URL" '//?fmt=tgz&resolve=skip' "$WORKDIR"/"$1"/"$2".tgz > "$TEMP_CLI_OUTPUT" 2>&1
  BASHERRCODE=$?
  zmlocalconfig -u socket_so_timeout
  CLI_OUT=$(cat "$TEMP_CLI_OUTPUT")
  if ! [[ $BASHERRCODE -eq 0 ]]; then
    if [[ "$CLI_OUT" == *"status=500"* ]]; then
      printf "\nNotice: postRestURL returned status=500 (empty chunk/boundary) for %s, continuing." "$2"
    else
      printf "\nError during the restore process for account %s. Error message below:\n%s\n" "$2" "$CLI_OUT"
    fi
  fi
  rm -rf "${TEMP_CLI_OUTPUT:?}"
}

###############################################################################
# audit_mailboxes: Audit message count and mailbox size with beautiful tables
###############################################################################
function audit_mailboxes()
{
  local target_account=""
  for arg in "$@"; do
    case "$arg" in
      -S|--sort-size|--sort-by-size)
        export SORT_BY="size"
        ;;
      --sort-size-asc)
        export SORT_BY="size-asc"
        ;;
      --sort=*)
        export SORT_BY="${arg#*=}"
        ;;
      size|size-desc)
        export SORT_BY="size"
        ;;
      size-asc)
        export SORT_BY="size-asc"
        ;;
      *)
        if [ -z "$target_account" ] && [ -n "$arg" ]; then
          target_account="$arg"
        fi
        ;;
    esac
  done
  init_table_theme

  if [ -n "$target_account" ]; then
    local widths=(57 12 12 10)
    local msgs
    msgs=$($ZMMAILBOX -z -m "$target_account" gaf 2>/dev/null | awk '$1 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ && $4 ~ /^[0-9]+$/ {sum += $4} END {print sum+0}')
    local bytes
    bytes=$(zmprov gqu localhost 2>/dev/null | awk -v a="$target_account" '$1 == a {print $3}')
    [ -z "$bytes" ] && bytes=0
    local hsize
    hsize=$(format_bytes "${bytes:-0}")
    local astatus="OK"
    [ "${msgs:-0}" -eq 0 ] && [ "${bytes:-0}" -eq 0 ] && astatus="EMPTY"
    local sclr
    sclr=$(get_status_color "$astatus")

    echo ""
    printf "  ${CLR_BOLD_CYAN}%s: ${CLR_BOLD_WHITE}%s${CLR_RESET}\n" "Mailbox Audit" "$target_account"
    draw_table_border top "${widths[@]}"
    printf "${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-55s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET}\n" \
      "$BOX_V" "Account / Mailbox" "$BOX_V" "Messages" "$BOX_V" "Size" "$BOX_V" "Status" "$BOX_V"
    draw_table_border mid "${widths[@]}"
    printf "${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_WHITE}%-55s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_CYAN}%10d${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_GREEN}%10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} %b%-8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET}\n" \
      "$BOX_V" "$target_account" "$BOX_V" "${msgs:-0}" "$BOX_V" "$hsize" "$BOX_V" "$sclr" "$astatus" "$BOX_V"
    draw_table_border bot "${widths[@]}"
    echo ""
    return 0
  fi

  echo ""
  printf "  ${CLR_BOLD_CYAN}%s${CLR_RESET}\n" "System Mailbox Message & Storage Audit"

  # Pre-fetch all mailbox used bytes from zmprov gqu in a single fast call
  local gqu_cache
  gqu_cache=$(mktemp)
  zmprov gqu localhost 2>/dev/null > "$gqu_cache"

  # Obtain accounts list
  local accounts=()
  local raw_accounts
  raw_accounts=$(zmprov -l gaa 2>/dev/null | sort)
  for acc in $raw_accounts; do
    if [ -f "/etc/cmbackup/blockedlist.conf" ] && grep -Fxq "$acc" /etc/cmbackup/blockedlist.conf 2>/dev/null; then
      continue
    fi
    accounts+=("$acc")
  done

  if [ "${#accounts[@]}" -eq 0 ]; then
    draw_empty_box "No active accounts found to audit." 96
    rm -f "$gqu_cache"
    return 0
  fi

  # Sort accounts by mailbox size if requested
  if [[ "${SORT_BY:-}" == "size" || "${SORT_BY:-}" == "size-desc" ]]; then
    local sorted_accs=()
    while IFS= read -r acc; do
      [ -n "$acc" ] && sorted_accs+=("$acc")
    done < <(
      for a in "${accounts[@]}"; do
        local b; b=$(awk -v acc="$a" '$1 == acc {print $3}' "$gqu_cache")
        [ -z "$b" ] && b=0
        printf "%016d %s\n" "$b" "$a"
      done | sort -rn | awk '{print $2}'
    )
    accounts=("${sorted_accs[@]}")
  elif [[ "${SORT_BY:-}" == "size-asc" ]]; then
    local sorted_accs=()
    while IFS= read -r acc; do
      [ -n "$acc" ] && sorted_accs+=("$acc")
    done < <(
      for a in "${accounts[@]}"; do
        local b; b=$(awk -v acc="$a" '$1 == acc {print $3}' "$gqu_cache")
        [ -z "$b" ] && b=0
        printf "%016d %s\n" "$b" "$a"
      done | sort -n | awk '{print $2}'
    )
    accounts=("${sorted_accs[@]}")
  fi

  local widths=(5 51 12 12 10)
  draw_table_border top "${widths[@]}"
  printf "${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%3s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-49s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET}\n" \
    "$BOX_V" "#" "$BOX_V" "Account / Mailbox" "$BOX_V" "Messages" "$BOX_V" "Size" "$BOX_V" "Status" "$BOX_V"
  draw_table_border mid "${widths[@]}"

  local idx=0
  local total_msgs=0
  local total_bytes=0

  for acc in "${accounts[@]}"; do
    idx=$((idx + 1))
    local msgs
    msgs=$($ZMMAILBOX -z -m "$acc" gaf 2>/dev/null | awk '$1 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ && $4 ~ /^[0-9]+$/ {sum += $4} END {print sum+0}')
    local bytes
    bytes=$(awk -v a="$acc" '$1 == a {print $3}' "$gqu_cache")
    [ -z "$bytes" ] && bytes=0
    local hsize
    hsize=$(format_bytes "$bytes")

    total_msgs=$((total_msgs + msgs))
    total_bytes=$((total_bytes + bytes))

    local astatus="OK"
    [ "${msgs:-0}" -eq 0 ] && [ "${bytes:-0}" -eq 0 ] && astatus="EMPTY"
    local sclr
    sclr=$(get_status_color "$astatus")

    printf "${CLR_GRAY}%s${CLR_RESET} ${CLR_GRAY}%3d${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_WHITE}%-49s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_CYAN}%10d${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_GREEN}%10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} %b%-8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET}\n" \
      "$BOX_V" "$idx" "$BOX_V" "$acc" "$BOX_V" "${msgs:-0}" "$BOX_V" "$hsize" "$BOX_V" "$sclr" "$astatus" "$BOX_V"
  done

  draw_table_border bot "${widths[@]}"
  rm -f "$gqu_cache"
  local total_hsize
  total_hsize=$(format_bytes "$total_bytes")
  if [[ "${SORT_BY:-}" == "size"* ]]; then
    printf "  ${CLR_DIM}Audit Total: %d accounts | %d total messages | %s total storage (sorted by size)${CLR_RESET}\n\n" "$idx" "$total_msgs" "$total_hsize"
  else
    printf "  ${CLR_DIM}Audit Total: %d accounts | %d total messages | %s total storage${CLR_RESET}\n\n" "$idx" "$total_msgs" "$total_hsize"
  fi
}

###############################################################################
# verify_account_messages: Audit / count messages in mailbox (backward compat)
###############################################################################
function verify_account_messages()
{
  audit_mailboxes "$1"
}


###############################################################################
# ldap_filter: Filter the account to see if you should do backup or not for that
#              account.
# Options:
# $1 - The email account to be validated.
###############################################################################
function ldap_filter()
{
  EXIST=
  if [[ "$LOCK_BACKUP" == "true" ]]; then
    if [[ "$SESSION_TYPE" == "TXT" ]]; then
      EXIST=$(grep "$1:$(date +%m/%d/%y)" "$WORKDIR"/sessions.txt 2> /dev/null | tail -1)
    else
      START_OF_TODAY=$(date +%Y-%m-%dT00:00:00.000000000)
      EXIST=$(sqlite3 "$WORKDIR"/sessions.sqlite3 "select email from backup_account where conclusion_date > '$START_OF_TODAY' and email='$1'")
    fi
  fi
  grep -Fxq "$1" /etc/cmbackup/blockedlist.conf
  BASHERRCODE=$?
  if [[ $BASHERRCODE -eq 0 ]]; then
    echo "WARN: $1 found inside blocked list - Nothing to do."
  elif [[ $EXIST ]]; then
    echo "WARN: $1 already has backup today. Nothing to do."
  else
    echo "$1" >> "$TEMPACCOUNT"
  fi
}
