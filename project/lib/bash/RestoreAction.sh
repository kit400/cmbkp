#!/bin/bash
################################################################################
# Restore Session - LDAP/Mailbox/DistList/Alias
################################################################################

################################################################################
# restore_main_mailbox: Manage the restore action for one or all mailbox
# Options:
#    $1 - The session to be restored
#    $2 - The list of accounts to be restored.
#    $3 - The destination of the restored account
################################################################################
function restore_main_mailbox()
{
  if [[ $SESSION_TYPE == 'TXT' ]]; then
    SESSION=$(grep -E ": $1 started" "$WORKDIR"/sessions.txt | grep 'started' | \
                  awk '{print $2}' | sort | uniq)
  elif [[ $SESSION_TYPE == "SQLITE3" ]]; then
    SESSION=$(sqlite3 "$WORKDIR"/sessions.sqlite3 "select * from backup_session where sessionID='$1'")
  fi
  if [ -n "$SESSION" ]; then
    check_disk_space "$WORKDIR" "$MIN_FREE_DISK_GB"
    printf "Restore mail process with session %s started at %s\n" "$1" "$(date)"
    if [[ -n $3 && $2 == *"@"* ]]; then
      if [ ! -f "$WORKDIR/$1/$2.tgz" ]; then
        printf "Account %s archive does not exist in %s/%s - skipping...\n" "$2" "$WORKDIR" "$1"
      else
        TEMP_CLI_OUTPUT=$(mktemp)
        zmlocalconfig -e socket_so_timeout=99999999
        $ZMMAILBOX -t 0 -z -m "$3" postRestURL -u "$ZMMAILBOX_URL" '//?fmt=tgz&resolve=skip' "$WORKDIR"/"$1"/"$2".tgz > "$TEMP_CLI_OUTPUT" 2>&1
        BASHERRCODE=$?
        zmlocalconfig -u socket_so_timeout
        CLI_OUT=$(cat "$TEMP_CLI_OUTPUT")
        if ! [[ $BASHERRCODE -eq 0 ]]; then
          printf "Error during the restore process for account %s:\n%s\n" "$2" "$CLI_OUT"
        fi
        rm -rf "${TEMP_CLI_OUTPUT:?}"
      fi
    else
      build_listRST "$1" "$2"
      parallel --jobs "$MAX_PARALLEL_PROCESS" "mailbox_restore '$1' '{}'" < "$TEMPACCOUNT"
    fi
    printf "\nRestore mail process with session %s completed at %s\n" "$1" "$(date)"
  else
    echo "Session $1 not found in database. Closing..."
    rm -rf "$PID"
  fi
}

################################################################################
# restore_main_ldap: Manage the restore action for one or all ldap accounts
# Options:
#    $1 - The session to be restored
#    $2 - The list of accounts to be restored.
################################################################################
function restore_main_ldap()
{
  if [[ $SESSION_TYPE == 'TXT' ]]; then
    SESSION=$(grep -E ": $1 started" "$WORKDIR"/sessions.txt 2>/dev/null | grep 'started' | \
                  awk '{print $2}' | sort | uniq)
  elif [[ $SESSION_TYPE == "SQLITE3" ]]; then
    SESSION=$(sqlite3 "$WORKDIR"/sessions.sqlite3 "select * from backup_session where sessionID='$1'" 2>/dev/null)
  fi
  if [ -n "$SESSION" ]; then
    printf "Restore LDAP process with session %s started at %s\n" "$1" "$(date)"
    build_listRST "$1" "$2"
    parallel --jobs "$MAX_PARALLEL_PROCESS" "ldap_restore '$1' '{}'" < "$TEMPACCOUNT"
    printf "\nRestore LDAP process with session %s completed at %s\n\n" "$1" "$(date)"
  else
    echo "Session $1 not found in database. Closing..."
  fi
}
