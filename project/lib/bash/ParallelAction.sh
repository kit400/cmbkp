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
# verify_account_messages: Audit / count messages in mailbox (from z2c)
###############################################################################
function verify_account_messages()
{
  local acc="$1"
  local msgs
  msgs=$($ZMMAILBOX -z -m "$acc" gaf 2>/dev/null | awk '$1 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ && $4 ~ /^[0-9]+$/ {sum += $4} END {print sum+0}')
  printf "  [AUDIT] %-35s : %6d messages\n" "$acc" "$msgs"
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
