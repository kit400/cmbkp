#!/bin/bash
################################################################################
# CMBKP INTERACTIVE TUI (FZF-POWERED)
# Fast interactive search for backup and restore operations
# Clean styling: colors and large dots (●), no emojis
################################################################################
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -f "$LIB_DIR/TableHelper.sh" ] && source "$LIB_DIR/TableHelper.sh"
[ -f "$LIB_DIR/SessionAction.sh" ] && source "$LIB_DIR/SessionAction.sh"

################################################################################
# check_fzf: Verify fzf binary is installed
################################################################################
function check_fzf() {
  if ! command -v fzf &>/dev/null; then
    init_table_theme
    draw_empty_box "Error: 'fzf' is not installed. Please install it with: apt install -y fzf (Ubuntu/Debian) or dnf install -y fzf (RHEL/Rocky)" 96
    return 1
  fi
  if [ ! -t 0 ] || [ ! -t 1 ]; then
    echo "Error: TUI requires an interactive terminal (TTY)."
    return 1
  fi
  return 0
}

################################################################################
# tui_pause: Pause and wait for user keypress before returning to menu
################################################################################
function tui_pause() {
  local prompt_msg="${1:-Нажмите Enter для возврата в меню... / Press Enter to continue...}"
  echo ""
  printf "  %b●%b %b%s%b " "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_WHITE:-}" "$prompt_msg" "${CLR_RESET:-}"
  read -r _dummy
}

################################################################################
# tui_get_all_accounts: Fetch active accounts via LDAP or zmprov
################################################################################
function tui_get_all_accounts() {
  local cache_file="/tmp/cmbkp_acc_cache_$UID"
  local now
  now=$(date +%s)
  local mtime=0
  [ -f "$cache_file" ] && mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo 0)

  # Refresh cache if older than 120 seconds or empty
  if [ ! -s "$cache_file" ] || [ $((now - mtime)) -gt 120 ]; then
    local accounts=""
    if [ -n "$LDAPSERVER" ] && [ -n "$LDAPADMIN" ] && [ -n "$LDAPPASS" ]; then
      accounts=$(ldapsearch -Z -x -H "$LDAPSERVER" -D "$LDAPADMIN" -w "$LDAPPASS" -b "" -LLL "(&(objectClass=zimbraAccount)(!(zimbraIsSystemResource=TRUE))(!(zimbraIsExternalVirtualAccount=TRUE)))" mail 2>/dev/null | grep "^mail: " | awk '{print $2}' | sort -u)
      if [ -z "$accounts" ]; then
        accounts=$(ldapsearch -x -H "$LDAPSERVER" -D "$LDAPADMIN" -w "$LDAPPASS" -b "" -LLL "(&(objectClass=zimbraAccount)(!(zimbraIsSystemResource=TRUE))(!(zimbraIsExternalVirtualAccount=TRUE)))" mail 2>/dev/null | grep "^mail: " | awk '{print $2}' | sort -u)
      fi
    fi
    if [ -z "$accounts" ] && command -v zmprov &>/dev/null; then
      accounts=$(zmprov -l gaa 2>/dev/null | sort -u)
    fi
    if [ -z "$accounts" ] && [ -x "/opt/zextras/bin/zmprov" ]; then
      accounts=$(/opt/zextras/bin/zmprov -l gaa 2>/dev/null | sort -u)
    fi

    # Filter blockedlist if exists
    local blocked_file="/etc/cmbkp/blockedlist.conf"
    [ ! -f "$blocked_file" ] && [ -f "/etc/cmbackup/blockedlist.conf" ] && blocked_file="/etc/cmbackup/blockedlist.conf"

    > "$cache_file"
    for acc in $accounts; do
      if [ -f "$blocked_file" ] && grep -Fxq "$acc" "$blocked_file" 2>/dev/null; then
        continue
      fi
      echo "$acc" >> "$cache_file"
    done
  fi

  cat "$cache_file"
}

################################################################################
# tui_preview_account: Output rich details for an account inside fzf preview pane
################################################################################
function tui_preview_account() {
  local acc="$1"
  [ -z "$acc" ] && return 0
  init_table_theme

  printf "${CLR_BOLD_CYAN}══════════════════════════════════════════════════════════════════${CLR_RESET}\n"
  printf " ${CLR_BOLD_WHITE}Account:${CLR_RESET} ${CLR_CYAN}%s${CLR_RESET}\n" "$acc"
  printf "${CLR_BOLD_CYAN}══════════════════════════════════════════════════════════════════${CLR_RESET}\n\n"

  # Live Mailbox Storage (from gqu cache if available)
  if [ -f "/tmp/gqu.txt" ]; then
    local live_bytes
    live_bytes=$(awk -v a="$acc" '$1 == a {print $3}' /tmp/gqu.txt 2>/dev/null)
    if [ -n "$live_bytes" ]; then
      printf " ${CLR_BOLD}Live Mailbox Storage:${CLR_RESET} %s\n\n" "$(format_bytes "$live_bytes")"
    fi
  fi

  printf " ${CLR_BOLD_YELLOW}Available Backup Sessions for this Account:${CLR_RESET}\n"
  local found_count=0

  if [[ "${SESSION_TYPE:-TXT}" == "SQLITE3" ]] && [ -f "$WORKDIR/sessions.sqlite3" ]; then
    local db_sessions
    db_sessions=$(sqlite3 "$WORKDIR/sessions.sqlite3" "SELECT sessionID, date(conclusion_date), account_size FROM backup_account WHERE email='$acc' ORDER BY conclusion_date DESC;" 2>/dev/null)
    while IFS='|' read -r sess bdate asize; do
      [ -z "$sess" ] && continue
      found_count=$((found_count + 1))
      local tclr
      tclr=$(get_type_color "$sess")
      printf "   %b●%b %-26s  Size: %-8s  Date: %s\n" "$tclr" "${CLR_RESET}" "$sess" "${asize:-N/A}" "${bdate:-Unknown}"
    done <<< "$db_sessions"
  else
    if [ -f "$WORKDIR/sessions.txt" ]; then
      local txt_sessions
      txt_sessions=$(grep ":$acc:" "$WORKDIR/sessions.txt" 2>/dev/null | tail -15)
      while IFS=':' read -r sess _a bdate; do
        [ -z "$sess" ] && continue
        found_count=$((found_count + 1))
        local sz="N/A"
        if [ -d "$WORKDIR/$sess" ]; then
          sz=$(du -ch "$WORKDIR/$sess/$acc"* 2>/dev/null | grep total | awk '{print $1}')
          [ -z "$sz" ] && sz="N/A"
        fi
        local tclr
        tclr=$(get_type_color "$sess")
        printf "   %b●%b %-26s  Size: %-8s  Date: %s\n" "$tclr" "${CLR_RESET}" "$sess" "$sz" "${bdate:-Unknown}"
      done <<< "$txt_sessions"
    fi
  fi

  if [ "$found_count" -eq 0 ]; then
    printf "   ${CLR_DIM}(No prior backups found for this account)${CLR_RESET}\n"
  fi

  echo ""
  printf " ${CLR_BOLD_GREEN}Recent Stored Backup Archives:${CLR_RESET}\n"
  local file_count=0
  while read -r sz fpath; do
    [ -z "$fpath" ] && continue
    file_count=$((file_count + 1))
    printf "   %b●%b %-8s %s\n" "${CLR_BOLD_GREEN:-}" "${CLR_RESET:-}" "$sz" "$(basename "$fpath")"
  done < <(ls -lh "$WORKDIR"/*/"$acc"* 2>/dev/null | tail -8 | awk '{print $5, $9}')

  if [ "$file_count" -eq 0 ]; then
    printf "   ${CLR_DIM}(No physical archive files found on disk)${CLR_RESET}\n"
  fi
}

################################################################################
# tui_preview_session: Output rich session summary for fzf preview pane
################################################################################
function tui_preview_session() {
  local sess="$1"
  [ -z "$sess" ] && return 0
  init_table_theme

  local sess_prefix
  sess_prefix=$(echo "$sess" | cut -d"-" -f1)
  local type_name=""
  case "$sess_prefix" in
    "full")            type_name="Full Backup" ;;
    "inc")             type_name="Incremental Backup" ;;
    "distlist")        type_name="Distribution List" ;;
    "alias")           type_name="Alias Backup" ;;
    "ldap")            type_name="Account (LDAP)" ;;
    "mbox"|"mail")     type_name="Mailbox Backup" ;;
    "sig"|"signature") type_name="Signature Backup" ;;
    *)                 type_name="Backup" ;;
  esac
  local tclr
  tclr=$(get_type_color "$type_name")

  printf "${CLR_BOLD_CYAN}══════════════════════════════════════════════════════════════════${CLR_RESET}\n"
  printf " ${CLR_BOLD_WHITE}Session:${CLR_RESET} %s %b(%s)%b\n" "$sess" "$tclr" "$type_name" "${CLR_RESET}"
  printf "${CLR_BOLD_CYAN}══════════════════════════════════════════════════════════════════${CLR_RESET}\n\n"

  local total_sz="N/A"
  [ -d "$WORKDIR/$sess" ] && total_sz=$(du -sh "$WORKDIR/$sess" 2>/dev/null | awk '{print $1}')
  printf " ${CLR_BOLD}Directory:${CLR_RESET} %s/%s\n" "$WORKDIR" "$sess"
  printf " ${CLR_BOLD}Total Size:${CLR_RESET} %s\n\n" "$total_sz"

  printf " ${CLR_BOLD_YELLOW}Accounts included in this session:${CLR_RESET}\n"
  local acc_count=0
  if [[ "${SESSION_TYPE:-TXT}" == "SQLITE3" ]] && [ -f "$WORKDIR/sessions.sqlite3" ]; then
    local db_accs
    db_accs=$(sqlite3 "$WORKDIR/sessions.sqlite3" "SELECT email, account_size FROM backup_account WHERE sessionID='$sess' LIMIT 20;" 2>/dev/null)
    while IFS='|' read -r email asize; do
      [ -z "$email" ] && continue
      acc_count=$((acc_count + 1))
      printf "   %b●%b %-40s %8s\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "$email" "${asize:-N/A}"
    done <<< "$db_accs"
  else
    if [ -f "$WORKDIR/sessions.txt" ]; then
      while IFS=':' read -r _s email _date; do
        [ -z "$email" ] && continue
        acc_count=$((acc_count + 1))
        local asz="N/A"
        if [ -d "$WORKDIR/$sess" ]; then
          asz=$(du -ch "$WORKDIR/$sess/$email"* 2>/dev/null | grep total | awk '{print $1}')
          [ -z "$asz" ] && asz="N/A"
        fi
        printf "   %b●%b %-40s %8s\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "$email" "$asz"
        [ "$acc_count" -ge 20 ] && { printf "   ... (and more)\n"; break; }
      done < <(grep "^$sess:" "$WORKDIR/sessions.txt" 2>/dev/null)
    fi
  fi

  if [ "$acc_count" -eq 0 ]; then
    printf "   ${CLR_DIM}(No individual account entries recorded)${CLR_RESET}\n"
  fi
}

################################################################################
# tui_select_account: Interactive fzf selector for account(s)
# Args: $1 = prompt, $2 = multi_select (true/false)
################################################################################
function tui_select_account() {
  local prompt_str="${1:-Search Account > }"
  local multi="${2:-false}"
  local fzf_flags=(
    "--prompt=$prompt_str"
    "--height=85%"
    "--layout=reverse"
    "--border=rounded"
    "--margin=1"
    "--padding=1"
    "--info=inline"
    "--preview=cmbkp --preview-account {1}"
    "--preview-window=right:50%:wrap"
    "--header=↑/↓: Navigate | Enter: Select | Esc: Cancel $([ "$multi" == "true" ] && echo "| Tab: Multi-select")"
  )
  [ "$multi" == "true" ] && fzf_flags+=("-m")

  local accounts
  accounts=$(tui_get_all_accounts)
  if [ -z "$accounts" ]; then
    echo "Error: No accounts found on the system." >&2
    return 1
  fi

  echo "$accounts" | fzf "${fzf_flags[@]}"
}

################################################################################
# tui_backup_flow: Interactive Backup with fzf search
################################################################################
function tui_backup_flow() {
  check_fzf || return 1
  init_table_theme

  echo ""
  printf "  %b●%b %b%s%b\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_CYAN:-}" "Step 1: Select User Account(s) to Back Up" "${CLR_RESET:-}"
  printf "    %b%s%b\n\n" "${CLR_DIM:-}" "(Type to filter, Tab to select multiple, Enter to confirm)" "${CLR_RESET:-}"

  local selected_raw
  selected_raw=$(tui_select_account "Backup Account > " true)
  if [ -z "$selected_raw" ]; then
    printf "\n  %b●%b %s\n" "${CLR_BOLD_YELLOW:-}" "${CLR_RESET:-}" "Backup cancelled (no account selected)."
    sleep 1.2
    return 0
  fi

  local selected_accounts=()
  while IFS= read -r line; do
    [ -n "$line" ] && selected_accounts+=("$line")
  done <<< "$selected_raw"

  local acc_count="${#selected_accounts[@]}"
  local acc_list
  acc_list=$(IFS=','; echo "${selected_accounts[*]}")

  echo ""
  printf "  %b●%b %bSelected (%d account(s)):%b %s\n\n" "${CLR_BOLD_GREEN:-}" "${CLR_RESET:-}" "${CLR_BOLD_WHITE:-}" "$acc_count" "${CLR_RESET:-}" "$acc_list"

  printf "  %b●%b %b%s%b\n\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_CYAN:-}" "Step 2: Choose Backup Mode" "${CLR_RESET:-}"
  printf "    %b[1]%b  %b●%b  %-22s %b%s%b\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_BLUE:-}" "${CLR_RESET:-}" "Full Backup" "${CLR_DIM:-}" "(LDAP directory + all mailbox data)" "${CLR_RESET:-}"
  printf "    %b[2]%b  %b●%b  %-22s %b%s%b\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "Incremental Backup" "${CLR_DIM:-}" "(Changes since last backup)" "${CLR_RESET:-}"
  printf "    %b[3]%b  %b●%b  %-22s %b%s%b\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_GREEN:-}" "${CLR_RESET:-}" "Mailbox Only" "${CLR_DIM:-}" "(Skip LDAP metadata)" "${CLR_RESET:-}"
  printf "    %b[4]%b  %b●%b  %-22s %b%s%b\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_YELLOW:-}" "${CLR_RESET:-}" "LDAP Directory Only" "${CLR_DIM:-}" "(Accounts, aliases, distribution lists)" "${CLR_RESET:-}"
  printf "    %b[5]%b  %b●%b  %-22s %b%s%b\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_MAGENTA:-}" "${CLR_RESET:-}" "Dry-Run Test" "${CLR_DIM:-}" "(Simulate backup without writing data)" "${CLR_RESET:-}"
  printf "    %b[0]%b  %b●%b  %-22s\n" "${CLR_BOLD_RED:-}" "${CLR_RESET:-}" "${CLR_GRAY:-}" "${CLR_RESET:-}" "Cancel"
  echo ""
  printf "  %b●%b Enter choice [1-5, or 0 to cancel]: " "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}"
  read -r bkp_choice

  local cmd_args=()
  case "$bkp_choice" in
    1) cmd_args=("-f" "-a" "$acc_list") ;;
    2) cmd_args=("-i" "-a" "$acc_list") ;;
    3) cmd_args=("-f" "-m" "-a" "$acc_list") ;;
    4) cmd_args=("-f" "-ldp" "-a" "$acc_list") ;;
    5) cmd_args=("-f" "-a" "$acc_list" "--dry-run") ;;
    0|"")
      printf "\n  %b●%b Cancelled.\n" "${CLR_BOLD_YELLOW:-}" "${CLR_RESET:-}"
      sleep 1.2
      return 0
      ;;
    *)
      printf "\n  %b●%b Invalid choice. Aborting.\n" "${CLR_BOLD_RED:-}" "${CLR_RESET:-}"
      sleep 1.5
      return 1
      ;;
  esac

  echo ""
  printf "  %b●%b %bCommand to execute:%b %bcmbkp %s%b\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_WHITE:-}" "${CLR_RESET:-}" "${CLR_CYAN:-}" "${cmd_args[*]}" "${CLR_RESET:-}"
  printf "  %b●%b Proceed with backup? [Y/n]: " "${CLR_BOLD_YELLOW:-}" "${CLR_RESET:-}"
  read -r confirm
  if [[ "$confirm" =~ ^[Nn] ]]; then
    printf "\n  %b●%b %s\n" "${CLR_BOLD_YELLOW:-}" "${CLR_RESET:-}" "Aborted by user."
    sleep 1.2
    return 0
  fi

  echo ""
  cmbkp "${cmd_args[@]}"
  local rc=$?
  echo ""
  if [ $rc -eq 0 ]; then
    printf "  %b●%b %bРезервное копирование успешно завершено.%b\n" "${CLR_BOLD_GREEN:-}" "${CLR_RESET:-}" "${CLR_BOLD_GREEN:-}" "${CLR_RESET:-}"
  else
    printf "  %b●%b %bРезервное копирование завершено с ошибкой (код %d).%b\n" "${CLR_BOLD_RED:-}" "${CLR_RESET:-}" "${CLR_BOLD_RED:-}" "$rc" "${CLR_RESET:-}"
  fi
  tui_pause
  return $rc
}

################################################################################
# tui_restore_flow: Interactive Restore with fzf search
################################################################################
function tui_restore_flow() {
  check_fzf || return 1
  init_table_theme

  echo ""
  printf "  %b●%b %b%s%b\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_CYAN:-}" "Step 1: Select User Account to Restore" "${CLR_RESET:-}"
  printf "    %b%s%b\n\n" "${CLR_DIM:-}" "(Type to filter, Enter to select account)" "${CLR_RESET:-}"

  local selected_account
  selected_account=$(tui_select_account "Restore Account > " false)
  if [ -z "$selected_account" ]; then
    printf "\n  %b●%b %s\n" "${CLR_BOLD_YELLOW:-}" "${CLR_RESET:-}" "Restore cancelled (no account selected)."
    sleep 1.2
    return 0
  fi

  echo ""
  printf "  %b●%b %bTarget Account:%b %s\n\n" "${CLR_BOLD_GREEN:-}" "${CLR_RESET:-}" "${CLR_BOLD_WHITE:-}" "${CLR_RESET:-}" "$selected_account"

  # Find available sessions for this account
  local session_candidates=()
  if [[ "${SESSION_TYPE:-TXT}" == "SQLITE3" ]] && [ -f "$WORKDIR/sessions.sqlite3" ]; then
    while IFS='|' read -r s bdate asz; do
      [ -n "$s" ] && session_candidates+=("$(printf "%-26s │ %-10s │ %8s" "$s" "${bdate:-Unknown}" "${asz:-N/A}")")
    done < <(sqlite3 "$WORKDIR/sessions.sqlite3" "SELECT sessionID, date(conclusion_date), account_size FROM backup_account WHERE email='$selected_account' ORDER BY conclusion_date DESC;" 2>/dev/null)
  else
    if [ -f "$WORKDIR/sessions.txt" ]; then
      while IFS=':' read -r s _a bdate; do
        if [ -n "$s" ]; then
          local asz="N/A"
          [ -d "$WORKDIR/$s" ] && asz=$(du -ch "$WORKDIR/$s/$selected_account"* 2>/dev/null | grep total | awk '{print $1}')
          session_candidates+=("$(printf "%-26s │ %-10s │ %8s" "$s" "${bdate:-Unknown}" "${asz:-N/A}")")
        fi
      done < <(grep ":$selected_account:" "$WORKDIR/sessions.txt" 2>/dev/null | sort -u)
    fi
  fi

  if [ "${#session_candidates[@]}" -eq 0 ]; then
    draw_empty_box "No backup sessions found for $selected_account in $WORKDIR" 96
    tui_pause
    return 1
  fi

  printf "  %b●%b %b%s%b\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_CYAN:-}" "Step 2: Select Backup Session to Restore From" "${CLR_RESET:-}"
  local fzf_sess_flags=(
    "--prompt=Select Backup Session > "
    "--height=70%"
    "--layout=reverse"
    "--border=rounded"
    "--margin=1"
    "--header=Session ID                  │ Date       │ Size      (Enter: Confirm | Esc: Cancel)"
    "--preview=cmbkp --preview-session {1}"
    "--preview-window=right:50%:wrap"
  )

  local chosen_sess_line
  chosen_sess_line=$(printf "%s\n" "${session_candidates[@]}" | fzf "${fzf_sess_flags[@]}")
  if [ -z "$chosen_sess_line" ]; then
    printf "\n  %b●%b %s\n" "${CLR_BOLD_YELLOW:-}" "${CLR_RESET:-}" "Restore cancelled (no session selected)."
    sleep 1.2
    return 0
  fi

  local target_session
  target_session=$(echo "$chosen_sess_line" | awk '{print $1}')

  echo ""
  printf "  %b●%b %b%s%b\n\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_CYAN:-}" "Step 3: Choose Restore Destination & Type" "${CLR_RESET:-}"
  printf "    %b[1]%b  %b●%b  %-28s %b%s%b\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_BLUE:-}" "${CLR_RESET:-}" "Restore to original account" "${CLR_DIM:-}" "($selected_account)" "${CLR_RESET:-}"
  printf "    %b[2]%b  %b●%b  %-28s %b%s%b\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_YELLOW:-}" "${CLR_RESET:-}" "Restore to another account" "${CLR_DIM:-}" "(-ro origin destination)" "${CLR_RESET:-}"
  printf "    %b[3]%b  %b●%b  %-28s %b%s%b\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_PURPLE:-}" "${CLR_RESET:-}" "Restore LDAP metadata only" "${CLR_DIM:-}" "(Accounts, aliases, distribution lists)" "${CLR_RESET:-}"
  printf "    %b[4]%b  %b●%b  %-28s %b%s%b\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_GREEN:-}" "${CLR_RESET:-}" "Restore Mailbox data only" "${CLR_DIM:-}" "(Skip LDAP attributes)" "${CLR_RESET:-}"
  printf "    %b[0]%b  %b●%b  %-28s\n" "${CLR_BOLD_RED:-}" "${CLR_RESET:-}" "${CLR_GRAY:-}" "${CLR_RESET:-}" "Cancel"
  echo ""
  printf "  %b●%b Enter choice [1-4, or 0 to cancel]: " "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}"
  read -r rst_choice

  local cmd_args=()
  case "$rst_choice" in
    1)
      cmd_args=("-r" "$target_session" "$selected_account")
      ;;
    2)
      echo ""
      printf "  %b●%b Select destination account to receive restored data:\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}"
      local dest_account
      dest_account=$(tui_select_account "Destination Account > " false)
      if [ -z "$dest_account" ]; then
        printf "\n  %b●%b %s\n" "${CLR_BOLD_YELLOW:-}" "${CLR_RESET:-}" "Cancelled (no destination account selected)."
        sleep 1.2
        return 0
      fi
      cmd_args=("-r" "-ro" "$target_session" "$selected_account" "$dest_account")
      ;;
    3)
      cmd_args=("-r" "-ldp" "$target_session" "$selected_account")
      ;;
    4)
      cmd_args=("-r" "-m" "$target_session" "$selected_account")
      ;;
    0|"")
      printf "\n  %b●%b Cancelled.\n" "${CLR_BOLD_YELLOW:-}" "${CLR_RESET:-}"
      sleep 1.2
      return 0
      ;;
    *)
      printf "\n  %b●%b Invalid choice. Aborting.\n" "${CLR_BOLD_RED:-}" "${CLR_RESET:-}"
      sleep 1.5
      return 1
      ;;
  esac

  echo ""
  printf "  %b●%b %bCommand to execute:%b %bcmbkp %s%b\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_WHITE:-}" "${CLR_RESET:-}" "${CLR_YELLOW:-}" "${cmd_args[*]}" "${CLR_RESET:-}"
  printf "  %b●%b %bВНИМАНИЕ:%b Данная операция изменит/перезапишет данные почтового ящика.\n" "${CLR_BOLD_RED:-}" "${CLR_RESET:-}" "${CLR_BOLD_RED:-}" "${CLR_RESET:-}"
  printf "  %b●%b Вы уверены, что хотите продолжить? [y/N]: " "${CLR_BOLD_RED:-}" "${CLR_RESET:-}"
  read -r confirm_rst
  if [[ ! "$confirm_rst" =~ ^[Yy] ]]; then
    printf "\n  %b●%b %s\n" "${CLR_BOLD_YELLOW:-}" "${CLR_RESET:-}" "Restore cancelled."
    sleep 1.2
    return 0
  fi

  echo ""
  cmbkp "${cmd_args[@]}"
  local rc=$?
  echo ""
  if [ $rc -eq 0 ]; then
    printf "  %b●%b %bВосстановление успешно завершено.%b\n" "${CLR_BOLD_GREEN:-}" "${CLR_RESET:-}" "${CLR_BOLD_GREEN:-}" "${CLR_RESET:-}"
  else
    printf "  %b●%b %bВосстановление завершено с ошибкой (код %d).%b\n" "${CLR_BOLD_RED:-}" "${CLR_RESET:-}" "${CLR_BOLD_RED:-}" "$rc" "${CLR_RESET:-}"
  fi
  tui_pause
  return $rc
}

################################################################################
# tui_session_browser: Interactive session list with fzf
################################################################################
function tui_session_browser() {
  check_fzf || return 1
  init_table_theme

  local sessions=()
  if [ -f "$WORKDIR/sessions.txt" ]; then
    while IFS= read -r s; do
      [ -n "$s" ] && sessions+=("$s")
    done < <(grep -E 'SESSION:' "$WORKDIR/sessions.txt" 2>/dev/null | grep 'started' | awk '{print $2}' | sort -ur)
  elif [ -f "$WORKDIR/sessions.sqlite3" ]; then
    while IFS= read -r s; do
      [ -n "$s" ] && sessions+=("$s")
    done < <(sqlite3 "$WORKDIR/sessions.sqlite3" "SELECT sessionID FROM backup_session ORDER BY initial_date DESC;" 2>/dev/null)
  fi

  if [ "${#sessions[@]}" -eq 0 ]; then
    draw_empty_box "No backup sessions recorded in $WORKDIR" 96
    tui_pause
    return 0
  fi

  local chosen_session
  chosen_session=$(printf "%s\n" "${sessions[@]}" | fzf \
    --prompt="Select Session > " \
    --height=80% \
    --layout=reverse \
    --border=rounded \
    --margin=1 \
    --header="Enter: View Detailed Accounts Table | Esc: Return" \
    --preview="cmbkp --preview-session {1}" \
    --preview-window=right:55%:wrap)

  if [ -n "$chosen_session" ]; then
    cmbkp -l "$chosen_session"
    tui_pause
  fi
}

################################################################################
# tui_main_menu: Interactive top-level menu
################################################################################
function tui_main_menu() {
  check_fzf || return 1
  init_table_theme

  while true; do
    clear 2>/dev/null || echo ""
    local widths=(92)
    draw_table_border top "${widths[@]}"
    printf "${CLR_GRAY}%s${CLR_RESET} ${CLR_BOLD_CYAN}%-90s${CLR_RESET} ${CLR_GRAY}%s${CLR_RESET}\n" \
      "$BOX_V" "  CMBKP INTERACTIVE MANAGEMENT CONSOLE (TUI with FZF)" "$BOX_V"
    draw_table_border mid "${widths[@]}"
    printf "${CLR_GRAY}%s${CLR_RESET} %-90s ${CLR_GRAY}%s${CLR_RESET}\n" \
      "$BOX_V" "  Carbonio Backup & Disaster Recovery - Pair Programming Enhanced Edition" "$BOX_V"
    draw_table_border bot "${widths[@]}"
    echo ""

    printf "  %bChoose an action:%b\n\n" "${CLR_BOLD_WHITE:-}" "${CLR_RESET:-}"
    printf "    %b[1]%b  %b●%b  %-24s %b%s%b\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_BLUE:-}" "${CLR_RESET:-}" "Backup Account(s)" "${CLR_DIM:-}" "- Fuzzy search user & run full/inc backup" "${CLR_RESET:-}"
    printf "    %b[2]%b  %b●%b  %-24s %b%s%b\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_GREEN:-}" "${CLR_RESET:-}" "Restore Account" "${CLR_DIM:-}" "- Fuzzy search user, choose backup session & restore" "${CLR_RESET:-}"
    printf "    %b[3]%b  %b●%b  %-24s %b%s%b\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_YELLOW:-}" "${CLR_RESET:-}" "Browse Sessions" "${CLR_DIM:-}" "- Interactive session explorer with account preview" "${CLR_RESET:-}"
    printf "    %b[4]%b  %b●%b  %-24s %b%s%b\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_PURPLE:-}" "${CLR_RESET:-}" "Mailbox Storage Audit" "${CLR_DIM:-}" "- Audit live message counts & storage usage" "${CLR_RESET:-}"
    printf "    %b[5]%b  %b●%b  %-24s %b%s%b\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}" "List Sessions Table" "${CLR_DIM:-}" "- Display formatted 96-col box table (cmbkp -l -S)" "${CLR_RESET:-}"
    printf "    %b[0]%b  %b●%b  %-24s %b%s%b\n" "${CLR_BOLD_RED:-}" "${CLR_RESET:-}" "${CLR_GRAY:-}" "${CLR_RESET:-}" "Exit TUI" "${CLR_DIM:-}" "- Return to shell" "${CLR_RESET:-}"
    echo ""
    printf "  %b●%b Select option [0-5]: " "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}"
    read -r menu_choice

    case "$menu_choice" in
      1) tui_backup_flow ;;
      2) tui_restore_flow ;;
      3) tui_session_browser ;;
      4)
        cmbkp -c -S
        tui_pause
        ;;
      5)
        cmbkp -l -S
        tui_pause
        ;;
      0|q|Q|"")
        echo ""
        printf "  %b●%b Exiting TUI. Goodbye!\n" "${CLR_BOLD_CYAN:-}" "${CLR_RESET:-}"
        break
        ;;
      *)
        echo "Invalid selection."
        sleep 1
        ;;
    esac
  done
}
