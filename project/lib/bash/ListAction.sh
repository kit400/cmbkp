#!/bin/bash
################################################################################
# Ldap Build List - No ldapadd or ldapdelete here
################################################################################

################################################################################
# build_listBKP: Build the list of accounts to be extracted via LDAP &/or Mailbox
# Options:
#    $1 - The type of object should be backed up. Valid values:
#        DLOBJECT - Distribution List;
#        ACOBJECT - User Account;
#        ALOBJECT - Alias;
#        SIOBJECT - Signature;
#    $2 - The filter used by LDAP to search for a type of object. Valid values:
#        DLFILTER - Distribution List (Use together with DLOBJECT);
#        ACFILTER - User Account (Use together with ACOBJECT);
#        ALFILTER - Alias (Use together with ALOBJECT).
#        SOFILTER - Signature (Use together with SIOBJECT).
#    $3 - Enable backup per domain
#    $4 - The list of domains to be backed up
################################################################################
function build_listBKP()
{
  if [ "$3" == "-d" ]; then
    for i in ${4//,/ }; do
      DC=",dc="
      DOMAIN="dc="${i//./$DC}
      ERR=$( (ldapsearch -Z -x -H "$LDAPSERVER" -D "$LDAPADMIN" -w "$LDAPPASS" -b "$DOMAIN" -LLL "$1" "$2" >> "$TEMPACCOUNT") 2>&1)
      BASHERRCODE=$?
      if [[ $BASHERRCODE -eq 0 ]]; then
        echo "Domain $i found! - Inserting inside the backup queue."
        logger -i -p local7.info "Domain $i found! - Inserting inside the backup queue."
      else
        logger -i -p local7.err "Cmbackup: LDAP - Can't extract accounts from LDAP - Error below:"
        logger -i -p local7.err "Cmbackup: $ERR"
        echo "ERROR - Can't extract accounts from LDAP - See log for more information"
        exit 1
      fi
    done
  else
    ERR=$( (ldapsearch -Z -x -H "$LDAPSERVER" -D "$LDAPADMIN" -w "$LDAPPASS" -b '' -LLL "$1" "$2" >> "$TEMPACCOUNT") 2>&1)
    BASHERRCODE=$?
    if [[ $BASHERRCODE -ne 0 ]]; then
      logger -i -p local7.err "Cmbackup: LDAP - Can't extract accounts from LDAP - Error below:"
      logger -i -p local7.err "Cmbackup: $ERR"
      echo "ERROR - Can't extract accounts from LDAP - See log for more information"
    fi
  fi
  grep "^$2" "$TEMPACCOUNT" | awk '{print $2}' > "$TEMPINACCOUNT"
  truncate --size 0 "$TEMPACCOUNT"
  parallel --jobs "$MAX_PARALLEL_PROCESS" "ldap_filter '{}'" < "$TEMPINACCOUNT"
  sort_accounts_by_size "$TEMPACCOUNT"
}

################################################################################
# sort_accounts_by_size: LPT (Longest Processing Time First) ordering (from z2c)
# Sorts accounts descending by mailbox size so largest mailboxes start first in parallel
################################################################################
function sort_accounts_by_size()
{
  local acc_file="$1"
  if [ ! -s "$acc_file" ]; then
    return 0
  fi
  local gqu_out
  gqu_out=$(zmprov gqu localhost 2>/dev/null)
  if [ -n "$gqu_out" ]; then
    local tmp_sorted
    tmp_sorted=$(mktemp)
    awk 'NR==FNR {size[$1]=$3; next} {s = ($1 in size ? size[$1] : 0); printf "%015d %s\n", s, $1}' <(echo "$gqu_out") "$acc_file" | sort -rn | awk '{print $2}' > "$tmp_sorted"
    if [ -s "$tmp_sorted" ]; then
      cat "$tmp_sorted" > "$acc_file"
    fi
    rm -f "$tmp_sorted"
  fi
}


################################################################################
# build_listRST: Build the list of accounts to be restored via LDAP &/or Mailbox
# Options:
#    $1 - The session to be restored;
#    $2 - The list of accounts to be restored.
################################################################################
function build_listRST()
{
  > "$TEMPACCOUNT"
  local session="$1"
  local arg1="$2"
  local arg2="$3"

  local target_accounts=""
  local target_domains=""

  if [[ "$arg1" == "-a" || "$arg1" == "--account" ]]; then
    target_accounts="$arg2"
  elif [[ "$arg1" == "-d" || "$arg1" == "--domain" ]]; then
    target_domains="$arg2"
  elif [[ "$arg1" == *"@"* ]]; then
    target_accounts="$arg1"
  elif [ -n "$arg1" ]; then
    # Passed as domain without -d flag (e.g. cmbkp -r session domain.com)
    target_domains="$arg1"
  fi

  if [ -n "$target_accounts" ]; then
    for i in ${target_accounts//,/ }; do
      echo "$i" >> "$TEMPACCOUNT"
    done
    sort -u "$TEMPACCOUNT" -o "$TEMPACCOUNT"
    return 0
  fi

  # Fetch all accounts from session
  local all_session_accs=()
  if [[ $SESSION_TYPE == 'TXT' ]]; then
    while IFS= read -r acc; do
      [ -n "$acc" ] && all_session_accs+=("$acc")
    done < <(grep "^${session}:" "$WORKDIR"/sessions.txt 2>/dev/null | cut -d: -f2 | sort -u)
  else
    while IFS= read -r acc; do
      [ -n "$acc" ] && all_session_accs+=("$acc")
    done < <(cmbkp_sqlite "$WORKDIR"/sessions.sqlite3 "select email from backup_account where sessionID='$session';" 2>/dev/null | sort -u)
  fi

  if [ -n "$target_domains" ]; then
    for dom in ${target_domains//,/ }; do
      dom="${dom#@}" # strip leading @ if provided
      for acc in "${all_session_accs[@]}"; do
        if [[ "$acc" == *"@$dom" ]]; then
          echo "$acc" >> "$TEMPACCOUNT"
        fi
      done
    done
    sort -u "$TEMPACCOUNT" -o "$TEMPACCOUNT"
  else
    for acc in "${all_session_accs[@]}"; do
      echo "$acc" >> "$TEMPACCOUNT"
    done
  fi
}
