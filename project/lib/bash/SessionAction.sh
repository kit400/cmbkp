#!/bin/bash
################################################################################
# Session List Functions
################################################################################
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -f "$LIB_DIR/TableHelper.sh" ] && source "$LIB_DIR/TableHelper.sh"

################################################################################
# list_sessions: Dispatch to list_session_detail or format-specific list function
################################################################################
function list_sessions()
{
  init_table_theme

  if [ -n "$1" ]; then
    list_session_detail "$1"
    return $?
  fi

  if [[ $SESSION_TYPE == 'TXT' ]]; then
    list_sessions_txt
  elif [[ $SESSION_TYPE == "SQLITE3" ]]; then
    list_sessions_sqlite3
  else
    echo "Invalid File Format - Nothing to do."
  fi
}

################################################################################
# list_sessions_txt: List all the sessions stored inside the server - TXT
################################################################################
function list_sessions_txt ()
{
  init_table_theme

  if [ ! -f "$WORKDIR/sessions.txt" ]; then
    draw_empty_box "No backup sessions found in $WORKDIR" 64
    return 0
  fi

  local session_list
  session_list=$(grep -E 'SESSION:' "$WORKDIR"/sessions.txt 2>/dev/null | grep 'started' | awk '{print $2}' | sort -u)
  if [ -z "$session_list" ]; then
    draw_empty_box "No backup sessions found in $WORKDIR" 64
    return 0
  fi

  local col_widths=(25 12 20 10 10 12)
  draw_table_border top "${col_widths[@]}"
  printf "${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-23s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-18s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET}\n" \
    "$BOX_V" "Session Name" "$BOX_V" "Date" "$BOX_V" "Type" "$BOX_V" "Accounts" "$BOX_V" "Size" "$BOX_V" "Status" "$BOX_V"
  draw_table_border mid "${col_widths[@]}"

  local total_sessions=0
  local total_accounts=0

  for i in $session_list; do
    local SIZE="N/A"
    [ -d "$WORKDIR/$i" ] && SIZE=$(du -sh "$WORKDIR/$i" 2>/dev/null | awk '{print $1}')
    [ -z "$SIZE" ] && SIZE="0B"

    local OPT
    OPT=$(echo "$i" | cut -d"-" -f1)
    case $OPT in
      "full")       OPT="Full Backup" ;;
      "inc")        OPT="Incremental Backup" ;;
      "distlist")   OPT="Distribution List" ;;
      "alias")      OPT="Alias Backup" ;;
      "ldap")       OPT="Account (LDAP)" ;;
      "mbox"|"mail") OPT="Mailbox Backup" ;;
      "sig"|"signature") OPT="Signature Backup" ;;
      *)            OPT="$OPT" ;;
    esac

    local DATE_RAW
    DATE_RAW=$(echo "$i" | cut -d"-" -f2)
    local YEAR="${DATE_RAW:0:4}"
    local MONTH="${DATE_RAW:4:2}"
    local DAY="${DATE_RAW:6:2}"
    local DATE_STR="${YEAR}-${MONTH}-${DAY}"
    [ -z "$YEAR" ] && DATE_STR="Unknown"

    local ACC_COUNT
    ACC_COUNT=$(grep -c "^${i}:" "$WORKDIR/sessions.txt" 2>/dev/null || echo 0)
    total_accounts=$((total_accounts + ACC_COUNT))
    total_sessions=$((total_sessions + 1))

    local STATUS="INCOMPLETE"
    if grep -q "SESSION: $i completed" "$WORKDIR/sessions.txt" 2>/dev/null; then
      STATUS="FINISHED"
    elif [ -f "$PID" ] && kill -0 "$(cat "$PID" 2>/dev/null)" 2>/dev/null; then
      STATUS="RUNNING"
    fi

    local STATUS_CLR
    STATUS_CLR=$(get_status_color "$STATUS")

    printf "${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_WHITE}%-23s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} %-10s ${CLR_GRAY}%s${CLR_RESET} %-18s ${CLR_GRAY}%s${CLR_RESET} ${CLR_CYAN}%8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_GREEN}%8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} %b%-10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET}\n" \
      "$BOX_V" "$i" "$BOX_V" "$DATE_STR" "$BOX_V" "$OPT" "$BOX_V" "$ACC_COUNT" "$BOX_V" "$SIZE" "$BOX_V" "$STATUS_CLR" "$STATUS" "$BOX_V"
  done

  draw_table_border bot "${col_widths[@]}"
  printf "  ${CLR_DIM}Total: %d session(s), %d account(s) backed up in %s${CLR_RESET}\n" "$total_sessions" "$total_accounts" "$WORKDIR"
}

################################################################################
# list_sessions_sqlite3: List all the sessions stored inside the server - SQLITE3
################################################################################
function list_sessions_sqlite3 ()
{
  init_table_theme

  if [ ! -f "$WORKDIR/sessions.sqlite3" ]; then
    draw_empty_box "No SQLite3 database found in $WORKDIR" 64
    return 0
  fi

  local rows
  rows=$(sqlite3 "$WORKDIR/sessions.sqlite3" "SELECT sessionID, date(initial_date), type, size, status FROM backup_session ORDER BY initial_date DESC;" 2>/dev/null)
  if [ -z "$rows" ]; then
    draw_empty_box "No backup sessions found in $WORKDIR" 64
    return 0
  fi

  local col_widths=(25 12 20 10 10 12)
  draw_table_border top "${col_widths[@]}"
  printf "${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-23s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-18s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET}\n" \
    "$BOX_V" "Session Name" "$BOX_V" "Date" "$BOX_V" "Type" "$BOX_V" "Accounts" "$BOX_V" "Size" "$BOX_V" "Status" "$BOX_V"
  draw_table_border mid "${col_widths[@]}"

  local total_sessions=0
  local total_accounts=0

  while IFS='|' read -r NAME DATE TYPE SIZE STATUS; do
    [ -z "$NAME" ] && continue
    total_sessions=$((total_sessions + 1))

    local ACC_COUNT
    ACC_COUNT=$(sqlite3 "$WORKDIR/sessions.sqlite3" "SELECT count(*) FROM backup_account WHERE sessionID='$NAME';" 2>/dev/null || echo 0)
    total_accounts=$((total_accounts + ACC_COUNT))

    if [ -z "$SIZE" ] || [ "$SIZE" == "null" ]; then
      if [ -d "$WORKDIR/$NAME" ]; then
        SIZE=$(du -sh "$WORKDIR/$NAME" 2>/dev/null | awk '{print $1}')
      else
        SIZE="N/A"
      fi
    fi
    [ -z "$STATUS" ] && STATUS="UNKNOWN"

    local STATUS_CLR
    STATUS_CLR=$(get_status_color "$STATUS")

    printf "${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_WHITE}%-23s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} %-10s ${CLR_GRAY}%s${CLR_RESET} %-18s ${CLR_GRAY}%s${CLR_RESET} ${CLR_CYAN}%8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_GREEN}%8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} %b%-10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET}\n" \
      "$BOX_V" "$NAME" "$BOX_V" "$DATE" "$BOX_V" "$TYPE" "$BOX_V" "$ACC_COUNT" "$BOX_V" "$SIZE" "$BOX_V" "$STATUS_CLR" "$STATUS" "$BOX_V"
  done <<< "$rows"

  draw_table_border bot "${col_widths[@]}"
  printf "  ${CLR_DIM}Total: %d session(s), %d account(s) recorded in database${CLR_RESET}\n" "$total_sessions" "$total_accounts"
}

################################################################################
# list_session_detail: Detail listing of accounts inside a specific session
################################################################################
function list_session_detail()
{
  local session="$1"
  init_table_theme

  local session_exists=0
  if [[ $SESSION_TYPE == 'TXT' ]]; then
    if [ -f "$WORKDIR/sessions.txt" ] && grep -q "SESSION: $session " "$WORKDIR/sessions.txt" 2>/dev/null; then
      session_exists=1
    fi
  elif [[ $SESSION_TYPE == 'SQLITE3' ]]; then
    local cnt
    cnt=$(sqlite3 "$WORKDIR/sessions.sqlite3" "SELECT count(*) FROM backup_session WHERE sessionID='$session';" 2>/dev/null || echo 0)
    [ "$cnt" -gt 0 ] && session_exists=1
  fi
  [ -d "$WORKDIR/$session" ] && session_exists=1

  if [ "$session_exists" -eq 0 ]; then
    draw_empty_box "Session '$session' not found in $WORKDIR" 64
    return 1
  fi

  local widths=(5 44 12 12 10)
  echo ""
  printf "  ${CLR_BOLD_CYAN}%s: ${CLR_BOLD_WHITE}%s${CLR_RESET}\n" "Session Details" "$session"
  draw_table_border top "${widths[@]}"
  printf "${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%3s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-42s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET}\n" \
    "$BOX_V" "#" "$BOX_V" "Account / Mailbox" "$BOX_V" "Size" "$BOX_V" "Date" "$BOX_V" "Status" "$BOX_V"
  draw_table_border mid "${widths[@]}"

  local idx=0
  if [[ $SESSION_TYPE == 'TXT' ]]; then
    local acc_lines
    acc_lines=$(grep "^${session}:" "$WORKDIR/sessions.txt" 2>/dev/null)
    while IFS=':' read -r _s acc bdate; do
      [ -z "$acc" ] && continue
      idx=$((idx + 1))
      local asize="N/A"
      local astatus="MISSING"
      if [ -d "$WORKDIR/$session" ]; then
        local found_files
        found_files=$(ls -1 "$WORKDIR/$session/$acc"* 2>/dev/null)
        if [ -n "$found_files" ]; then
          asize=$(du -ch "$WORKDIR/$session/$acc"* 2>/dev/null | grep total | awk '{print $1}')
          astatus="OK"
        fi
      fi
      local sclr
      sclr=$(get_status_color "$astatus")
      printf "${CLR_GRAY}%s${CLR_RESET} ${CLR_GRAY}%3d${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_WHITE}%-42s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_GREEN}%10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} %-10s ${CLR_GRAY}%s${CLR_RESET} %b%-8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET}\n" \
        "$BOX_V" "$idx" "$BOX_V" "$acc" "$BOX_V" "$asize" "$BOX_V" "$bdate" "$BOX_V" "$sclr" "$astatus" "$BOX_V"
    done <<< "$acc_lines"
  elif [[ $SESSION_TYPE == 'SQLITE3' ]]; then
    local acc_data
    acc_data=$(sqlite3 "$WORKDIR/sessions.sqlite3" "SELECT email, account_size, date(conclusion_date) FROM backup_account WHERE sessionID='$session';" 2>/dev/null)
    while IFS='|' read -r acc asize bdate; do
      [ -z "$acc" ] && continue
      idx=$((idx + 1))
      [ -z "$asize" ] && asize="N/A"
      local astatus="OK"
      [ "$asize" == "N/A" ] && astatus="MISSING"
      local sclr
      sclr=$(get_status_color "$astatus")
      printf "${CLR_GRAY}%s${CLR_RESET} ${CLR_GRAY}%3d${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_WHITE}%-42s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_GREEN}%10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} %-10s ${CLR_GRAY}%s${CLR_RESET} %b%-8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET}\n" \
        "$BOX_V" "$idx" "$BOX_V" "$acc" "$BOX_V" "$asize" "$BOX_V" "$bdate" "$BOX_V" "$sclr" "$astatus" "$BOX_V"
    done <<< "$acc_data"
  fi

  draw_table_border bot "${widths[@]}"
  local sess_size="N/A"
  [ -d "$WORKDIR/$session" ] && sess_size=$(du -sh "$WORKDIR/$session" 2>/dev/null | awk '{print $1}')
  printf "  ${CLR_DIM}Session: %s | Total Accounts: %d | Total Size: %s${CLR_RESET}\n\n" "$session" "$idx" "$sess_size"
}
