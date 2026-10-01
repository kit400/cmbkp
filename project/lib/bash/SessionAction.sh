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

  local target_session=""
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
        if [ -z "$target_session" ] && [ -n "$arg" ] && [ "$arg" != "date" ]; then
          target_session="$arg"
        fi
        ;;
    esac
  done

  if [ -n "$target_session" ]; then
    list_session_detail "$target_session"
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
    draw_empty_box "No backup sessions found in $WORKDIR" 96
    return 0
  fi

  local session_list
  session_list=$(grep -E 'SESSION:' "$WORKDIR"/sessions.txt 2>/dev/null | grep 'started' | awk '{print $2}' | sort -u)
  if [ -z "$session_list" ]; then
    draw_empty_box "No backup sessions found in $WORKDIR" 96
    return 0
  fi

  # Column order: Session Name | Type | Accounts | Date | Size | Status
  # Date is right before Size; both Date and Size have equal width (12 chars).
  local col_widths=(25 20 10 12 12 10)
  draw_table_border top "${col_widths[@]}"
  printf "${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-23s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-18s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET}\n" \
    "$BOX_V" "Session Name" "$BOX_V" "Type" "$BOX_V" "Accounts" "$BOX_V" "Date" "$BOX_V" "Size" "$BOX_V" "Status" "$BOX_V"
  draw_table_border mid "${col_widths[@]}"

  local total_sessions=0
  local total_accounts=0
  local session_records=()

  for i in $session_list; do
    local SIZE="N/A"
    local raw_bytes=0
    if [ -d "$WORKDIR/$i" ]; then
      SIZE=$(du -sh "$WORKDIR/$i" 2>/dev/null | awk '{print $1}')
      raw_bytes=$(du -sb "$WORKDIR/$i" 2>/dev/null | awk '{print $1}')
      [ -z "$raw_bytes" ] && raw_bytes=$(parse_size_bytes "$SIZE")
    fi
    [ -z "$SIZE" ] && SIZE="0B"
    [ -z "$raw_bytes" ] && raw_bytes=0

    local OPT
    OPT=$(echo "$i" | cut -d"-" -f1)
    case $OPT in
      "full")        OPT="Full Backup" ;;
      "inc")         OPT="Incremental Backup" ;;
      "distlist")    OPT="Distribution List" ;;
      "alias")       OPT="Alias Backup" ;;
      "ldap")        OPT="Account (LDAP)" ;;
      "mbox"|"mail") OPT="Mailbox Backup" ;;
      "sig"|"signature") OPT="Signature Backup" ;;
      *)             OPT="$OPT" ;;
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

    local row_entry
    row_entry=$(printf "%016d|%s|%s|%s|%s|%s|%s" "$raw_bytes" "$i" "$OPT" "$ACC_COUNT" "$DATE_STR" "$SIZE" "$STATUS")
    session_records+=("$row_entry")
  done

  # Sorting by size if requested
  local display_records=()
  if [[ "${SORT_BY:-}" == "size" || "${SORT_BY:-}" == "size-desc" ]]; then
    while IFS= read -r line; do
      [ -n "$line" ] && display_records+=("$line")
    done < <(printf "%s\n" "${session_records[@]}" | sort -t'|' -k1,1r -k2,2)
  elif [[ "${SORT_BY:-}" == "size-asc" ]]; then
    while IFS= read -r line; do
      [ -n "$line" ] && display_records+=("$line")
    done < <(printf "%s\n" "${session_records[@]}" | sort -t'|' -k1,1 -k2,2)
  else
    display_records=("${session_records[@]}")
  fi

  for rec in "${display_records[@]}"; do
    IFS='|' read -r _bytes SESS_NAME SESS_OPT SESS_ACCS SESS_DATE SESS_SIZE SESS_STATUS <<< "$rec"
    local STATUS_CLR
    STATUS_CLR=$(get_status_color "$SESS_STATUS")
    local TYPE_CLR
    TYPE_CLR=$(get_type_color "$SESS_OPT")

    printf "${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_WHITE}%-23s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} %b%-18s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_CYAN}%8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} %-10s ${CLR_GRAY}%s${CLR_RESET} ${CLR_GREEN}%10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} %b%-8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET}\n" \
      "$BOX_V" "$SESS_NAME" "$BOX_V" "$TYPE_CLR" "$SESS_OPT" "$BOX_V" "$SESS_ACCS" "$BOX_V" "$SESS_DATE" "$BOX_V" "$SESS_SIZE" "$BOX_V" "$STATUS_CLR" "$SESS_STATUS" "$BOX_V"
  done

  draw_table_border bot "${col_widths[@]}"
  if [[ "${SORT_BY:-}" == "size"* ]]; then
    printf "  ${CLR_DIM}Total: %d session(s), %d account(s) backed up in %s (sorted by size)${CLR_RESET}\n" "$total_sessions" "$total_accounts" "$WORKDIR"
  else
    printf "  ${CLR_DIM}Total: %d session(s), %d account(s) backed up in %s${CLR_RESET}\n" "$total_sessions" "$total_accounts" "$WORKDIR"
  fi
}

################################################################################
# list_sessions_sqlite3: List all the sessions stored inside the server - SQLITE3
################################################################################
function list_sessions_sqlite3 ()
{
  init_table_theme

  if [ ! -f "$WORKDIR/sessions.sqlite3" ]; then
    draw_empty_box "No SQLite3 database found in $WORKDIR" 96
    return 0
  fi

  local rows
  rows=$(sqlite3 "$WORKDIR/sessions.sqlite3" "SELECT sessionID, date(initial_date), type, size, status FROM backup_session ORDER BY initial_date DESC;" 2>/dev/null)
  if [ -z "$rows" ]; then
    draw_empty_box "No backup sessions found in $WORKDIR" 96
    return 0
  fi

  # Column order: Session Name | Type | Accounts | Date | Size | Status
  # Date is right before Size; both Date and Size have equal width (12 chars).
  local col_widths=(25 20 10 12 12 10)
  draw_table_border top "${col_widths[@]}"
  printf "${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-23s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-18s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET}\n" \
    "$BOX_V" "Session Name" "$BOX_V" "Type" "$BOX_V" "Accounts" "$BOX_V" "Date" "$BOX_V" "Size" "$BOX_V" "Status" "$BOX_V"
  draw_table_border mid "${col_widths[@]}"

  local total_sessions=0
  local total_accounts=0
  local session_records=()

  while IFS='|' read -r NAME DATE TYPE SIZE STATUS; do
    [ -z "$NAME" ] && continue
    total_sessions=$((total_sessions + 1))

    local ACC_COUNT
    ACC_COUNT=$(sqlite3 "$WORKDIR/sessions.sqlite3" "SELECT count(*) FROM backup_account WHERE sessionID='$NAME';" 2>/dev/null || echo 0)
    total_accounts=$((total_accounts + ACC_COUNT))

    local raw_bytes=0
    if [ -z "$SIZE" ] || [ "$SIZE" == "null" ]; then
      if [ -d "$WORKDIR/$NAME" ]; then
        SIZE=$(du -sh "$WORKDIR/$NAME" 2>/dev/null | awk '{print $1}')
        raw_bytes=$(du -sb "$WORKDIR/$NAME" 2>/dev/null | awk '{print $1}')
      else
        SIZE="N/A"
      fi
    else
      raw_bytes=$(parse_size_bytes "$SIZE")
    fi
    [ -z "$STATUS" ] && STATUS="UNKNOWN"
    [ -z "$raw_bytes" ] && raw_bytes=0

    local row_entry
    row_entry=$(printf "%016d|%s|%s|%s|%s|%s|%s" "$raw_bytes" "$NAME" "$TYPE" "$ACC_COUNT" "$DATE" "$SIZE" "$STATUS")
    session_records+=("$row_entry")
  done <<< "$rows"

  # Sorting by size if requested
  local display_records=()
  if [[ "${SORT_BY:-}" == "size" || "${SORT_BY:-}" == "size-desc" ]]; then
    while IFS= read -r line; do
      [ -n "$line" ] && display_records+=("$line")
    done < <(printf "%s\n" "${session_records[@]}" | sort -t'|' -k1,1r -k2,2)
  elif [[ "${SORT_BY:-}" == "size-asc" ]]; then
    while IFS= read -r line; do
      [ -n "$line" ] && display_records+=("$line")
    done < <(printf "%s\n" "${session_records[@]}" | sort -t'|' -k1,1 -k2,2)
  else
    display_records=("${session_records[@]}")
  fi

  for rec in "${display_records[@]}"; do
    IFS='|' read -r _bytes NAME TYPE ACC_COUNT DATE SIZE STATUS <<< "$rec"
    local STATUS_CLR
    STATUS_CLR=$(get_status_color "$STATUS")
    local TYPE_CLR
    TYPE_CLR=$(get_type_color "$TYPE")

    printf "${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_WHITE}%-23s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} %b%-18s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_CYAN}%8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} %-10s ${CLR_GRAY}%s${CLR_RESET} ${CLR_GREEN}%10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} %b%-8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET}\n" \
      "$BOX_V" "$NAME" "$BOX_V" "$TYPE_CLR" "$TYPE" "$BOX_V" "$ACC_COUNT" "$BOX_V" "$DATE" "$BOX_V" "$SIZE" "$BOX_V" "$STATUS_CLR" "$STATUS" "$BOX_V"
  done

  draw_table_border bot "${col_widths[@]}"
  if [[ "${SORT_BY:-}" == "size"* ]]; then
    printf "  ${CLR_DIM}Total: %d session(s), %d account(s) recorded in database (sorted by size)${CLR_RESET}\n" "$total_sessions" "$total_accounts"
  else
    printf "  ${CLR_DIM}Total: %d session(s), %d account(s) recorded in database${CLR_RESET}\n" "$total_sessions" "$total_accounts"
  fi
}

################################################################################
# list_session_detail: Detail listing of accounts inside a specific session
################################################################################
function list_session_detail()
{
  local session="$1"
  shift
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
    esac
  done
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
    draw_empty_box "Session '$session' not found in $WORKDIR" 96
    return 1
  fi

  local sess_prefix; sess_prefix=$(echo "$session" | cut -d"-" -f1)
  local type_name=""
  case "$sess_prefix" in
    "full")            type_name="Full Backup" ;;
    "inc")             type_name="Incremental Backup" ;;
    "distlist")        type_name="Distribution List" ;;
    "alias")           type_name="Alias Backup" ;;
    "ldap")            type_name="Account (LDAP)" ;;
    "mbox"|"mail")     type_name="Mailbox Backup" ;;
    "sig"|"signature") type_name="Signature Backup" ;;
    *)                 type_name="" ;;
  esac

  # Column order: # | Account / Mailbox | Date | Size | Status
  # Date and Size have equal width (12 chars), matching the main session list.
  local widths=(5 51 12 12 10)
  echo ""
  if [ -n "$type_name" ]; then
    local type_clr; type_clr=$(get_type_color "$type_name")
    printf "  ${CLR_BOLD_CYAN}%s: ${CLR_BOLD_WHITE}%s${CLR_RESET} %b(%s)${CLR_RESET}\n" "Session Details" "$session" "$type_clr" "$type_name"
  else
    printf "  ${CLR_BOLD_CYAN}%s: ${CLR_BOLD_WHITE}%s${CLR_RESET}\n" "Session Details" "$session"
  fi
  draw_table_border top "${widths[@]}"

  printf "${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%3s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-49s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET}\n" \
    "$BOX_V" "#" "$BOX_V" "Account / Mailbox" "$BOX_V" "Date" "$BOX_V" "Size" "$BOX_V" "Status" "$BOX_V"
  draw_table_border mid "${widths[@]}"

  local acc_records=()
  if [[ $SESSION_TYPE == 'TXT' ]]; then
    local acc_lines
    acc_lines=$(grep "^${session}:" "$WORKDIR/sessions.txt" 2>/dev/null)
    while IFS=':' read -r _s acc bdate; do
      [ -z "$acc" ] && continue

      # Normalize date to YYYY-MM-DD
      if [[ "$bdate" =~ ^([0-9]{2})/([0-9]{2})/([0-9]{2})$ ]]; then
        bdate="20${BASH_REMATCH[3]}-${BASH_REMATCH[1]}-${BASH_REMATCH[2]}"
      elif [ -z "$bdate" ]; then
        local raw_ts
        raw_ts=$(echo "$session" | cut -d'-' -f2)
        if [ -n "$raw_ts" ]; then
          bdate="${raw_ts:0:4}-${raw_ts:4:2}-${raw_ts:6:2}"
        else
          bdate="Unknown"
        fi
      fi

      local asize="N/A"
      local astatus="MISSING"
      local raw_bytes=0
      if [ -d "$WORKDIR/$session" ]; then
        local found_files
        found_files=$(ls -1 "$WORKDIR/$session/$acc"* 2>/dev/null)
        if [ -n "$found_files" ]; then
          asize=$(du -ch "$WORKDIR/$session/$acc"* 2>/dev/null | grep total | awk '{print $1}')
          raw_bytes=$(du -cb "$WORKDIR/$session/$acc"* 2>/dev/null | grep total | awk '{print $1}')
          [ -z "$raw_bytes" ] && raw_bytes=$(parse_size_bytes "$asize")
          astatus="FINISHED"
        fi
      fi
      [ -z "$raw_bytes" ] && raw_bytes=0
      acc_records+=("$(printf "%016d|%s|%s|%s|%s" "$raw_bytes" "$acc" "$bdate" "$asize" "$astatus")")
    done <<< "$acc_lines"
  elif [[ $SESSION_TYPE == 'SQLITE3' ]]; then
    local acc_data
    acc_data=$(sqlite3 "$WORKDIR/sessions.sqlite3" "SELECT email, account_size, date(conclusion_date) FROM backup_account WHERE sessionID='$session';" 2>/dev/null)
    while IFS='|' read -r acc asize bdate; do
      [ -z "$acc" ] && continue
      [ -z "$asize" ] && asize="N/A"
      [ -z "$bdate" ] && bdate="Unknown"
      local astatus="FINISHED"
      [ "$asize" == "N/A" ] && astatus="MISSING"
      local raw_bytes
      raw_bytes=$(parse_size_bytes "$asize")
      [ -z "$raw_bytes" ] && raw_bytes=0
      acc_records+=("$(printf "%016d|%s|%s|%s|%s" "$raw_bytes" "$acc" "$bdate" "$asize" "$astatus")")
    done <<< "$acc_data"
  fi

  # Sorting accounts by size if requested
  local display_records=()
  if [[ "${SORT_BY:-}" == "size" || "${SORT_BY:-}" == "size-desc" ]]; then
    while IFS= read -r line; do
      [ -n "$line" ] && display_records+=("$line")
    done < <(printf "%s\n" "${acc_records[@]}" | sort -t'|' -k1,1r -k2,2)
  elif [[ "${SORT_BY:-}" == "size-asc" ]]; then
    while IFS= read -r line; do
      [ -n "$line" ] && display_records+=("$line")
    done < <(printf "%s\n" "${acc_records[@]}" | sort -t'|' -k1,1 -k2,2)
  else
    display_records=("${acc_records[@]}")
  fi

  local idx=0
  for rec in "${display_records[@]}"; do
    IFS='|' read -r _bytes acc bdate asize astatus <<< "$rec"
    idx=$((idx + 1))
    local sclr
    sclr=$(get_status_color "$astatus")
    printf "${CLR_GRAY}%s${CLR_RESET} ${CLR_GRAY}%3d${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_WHITE}%-49s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} %-10s ${CLR_GRAY}%s${CLR_RESET} ${CLR_GREEN}%10s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET} %b%-8s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET}\n" \
      "$BOX_V" "$idx" "$BOX_V" "$acc" "$BOX_V" "$bdate" "$BOX_V" "$asize" "$BOX_V" "$sclr" "$astatus" "$BOX_V"
  done

  draw_table_border bot "${widths[@]}"
  local sess_size="N/A"
  [ -d "$WORKDIR/$session" ] && sess_size=$(du -sh "$WORKDIR/$session" 2>/dev/null | awk '{print $1}')
  if [[ "${SORT_BY:-}" == "size"* ]]; then
    printf "  ${CLR_DIM}Total: %d account(s) in session %s | Total Size: %s (sorted by size)${CLR_RESET}\n\n" "$idx" "$session" "$sess_size"
  else
    printf "  ${CLR_DIM}Total: %d account(s) in session %s | Total Size: %s${CLR_RESET}\n\n" "$idx" "$session" "$sess_size"
  fi
}

