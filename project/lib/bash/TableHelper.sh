#!/bin/bash
################################################################################
# CMBACKUP TABLE AND TERMINAL STYLING HELPER
# Modern Unicode box-drawing tables with ANSI colors and ASCII fallback
################################################################################

# Initialize color and box drawing variables
function init_table_theme() {
  # Terminal colors (enabled only for interactive TTY without NO_COLOR)
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [[ "${TERM:-}" != "dumb" ]]; then
    CLR_RESET='\033[0m'
    CLR_BOLD='\033[1m'
    CLR_DIM='\033[2m'
    CLR_CYAN='\033[36m'
    CLR_BOLD_CYAN='\033[1;36m'
    CLR_GREEN='\033[32m'
    CLR_BOLD_GREEN='\033[1;32m'
    CLR_YELLOW='\033[33m'
    CLR_BOLD_YELLOW='\033[1;33m'
    CLR_BLUE='\033[34m'
    CLR_BOLD_BLUE='\033[1;34m'
    CLR_MAGENTA='\033[35m'
    CLR_RED='\033[31m'
    CLR_BOLD_RED='\033[1;31m'
    CLR_GRAY='\033[90m'
    CLR_WHITE='\033[97m'
    CLR_BOLD_WHITE='\033[1;97m'
  else
    CLR_RESET=''
    CLR_BOLD=''
    CLR_DIM=''
    CLR_CYAN=''
    CLR_BOLD_CYAN=''
    CLR_GREEN=''
    CLR_BOLD_GREEN=''
    CLR_YELLOW=''
    CLR_BOLD_YELLOW=''
    CLR_BLUE=''
    CLR_BOLD_BLUE=''
    CLR_MAGENTA=''
    CLR_RED=''
    CLR_BOLD_RED=''
    CLR_GRAY=''
    CLR_WHITE=''
    CLR_BOLD_WHITE=''
  fi

  # Detect UTF-8 support for rounded box characters
  local charmap
  charmap=$(locale charmap 2>/dev/null || echo "")
  if [[ "$charmap" =~ [Uu][Tt][Ff]-?8 ]] || [[ "${LANG:-}" =~ [Uu][Tt][Ff]-?8 ]] || [[ "${LC_ALL:-}" =~ [Uu][Tt][Ff]-?8 ]] || [[ "${LC_CTYPE:-}" =~ [Uu][Tt][Ff]-?8 ]]; then
    BOX_TL="╭"
    BOX_TR="╮"
    BOX_BL="╰"
    BOX_BR="╯"
    BOX_H="─"
    BOX_V="│"
    BOX_TJ="┬"
    BOX_BJ="┴"
    BOX_LJ="├"
    BOX_RJ="┤"
    BOX_X="┼"
  else
    BOX_TL="+"
    BOX_TR="+"
    BOX_BL="+"
    BOX_BR="+"
    BOX_H="-"
    BOX_V="|"
    BOX_TJ="+"
    BOX_BJ="+"
    BOX_LJ="+"
    BOX_RJ="+"
    BOX_X="+"
  fi
}

# Repeat a character N times safely (supports multi-byte UTF-8)
function repeat_char() {
  local count="$1" char="$2" str=""
  if [ "$count" -le 0 ]; then
    return 0
  fi
  printf -v str "%*s" "$count" ""
  echo -n "${str// /$char}"
}

# Draw a table horizontal border (top, mid, bot)
# Usage: draw_table_border <top|mid|bot> <col1_width> <col2_width> ...
function draw_table_border() {
  local border_type="$1"; shift
  local widths=("$@")
  local left sep right

  case "$border_type" in
    top) left="$BOX_TL"; sep="$BOX_TJ"; right="$BOX_TR" ;;
    mid) left="$BOX_LJ"; sep="$BOX_X";  right="$BOX_RJ" ;;
    bot) left="$BOX_BL"; sep="$BOX_BJ"; right="$BOX_BR" ;;
    *)   left="$BOX_LJ"; sep="$BOX_X";  right="$BOX_RJ" ;;
  esac

  local out=""
  for i in "${!widths[@]}"; do
    local w="${widths[$i]}"
    local seg
    seg=$(repeat_char "$w" "$BOX_H")
    if [ "$i" -eq 0 ]; then
      out="${left}${seg}"
    else
      out="${out}${sep}${seg}"
    fi
  done
  out="${out}${right}"
  printf "${CLR_GRAY}%s${CLR_RESET}\n" "$out"
}

# Return color code for a status string
function get_status_color() {
  local status="$1"
  case "$status" in
    *FINISHED*|*COMPLETED*|*OK*|*SUCCESS*)
      echo "$CLR_BOLD_GREEN"
      ;;
    *PROGRESS*|*RUNNING*|*PENDING*)
      echo "$CLR_BOLD_YELLOW"
      ;;
    *FAIL*|*ERROR*|*INCOMPLETE*|*MISSING*)
      echo "$CLR_BOLD_RED"
      ;;
    *)
      echo "$CLR_RESET"
      ;;
  esac
}

# Return subtle/non-bright color code for a backup type string
function get_type_color() {
  local t="$1"
  if [ -z "${CLR_RESET:-}" ]; then
    echo ""
    return 0
  fi
  local has_256=0
  if [[ "${TERM:-}" =~ 256color ]] || [[ "${COLORTERM:-}" =~ (truecolor|24bit) ]]; then
    has_256=1
  fi

  case "$t" in
    *Full*)
      echo '\033[36m' ;;        # Calm Cyan
    *Incremental*)
      echo '\033[33m' ;;        # Calm Amber
    *Distribution*)
      echo '\033[35m' ;;        # Calm Magenta
    *Alias*)
      if [ "$has_256" -eq 1 ]; then echo '\033[38;5;110m'; else echo '\033[34m'; fi ;; # Steel Blue / Blue
    *LDAP*|*ldap*)
      if [ "$has_256" -eq 1 ]; then echo '\033[38;5;248m'; else echo '\033[37m'; fi ;; # Slate Gray / Light Gray
    *Mailbox*|*mbox*|*Mail*)
      echo '\033[32m' ;;        # Calm Green
    *Signature*|*sig*)
      if [ "$has_256" -eq 1 ]; then echo '\033[38;5;174m'; else echo '\033[35m'; fi ;; # Soft Coral / Magenta
    *)
      echo '\033[37m' ;;        # Subtle Text
  esac
}

# Format bytes to human readable format
function format_bytes() {
  local b="${1:-0}"
  if [ -z "$b" ] || ! [[ "$b" =~ ^[0-9]+$ ]]; then
    echo "0 B"
    return
  fi
  if [ "$b" -ge 1073741824 ]; then
    awk -v b="$b" 'BEGIN {printf "%.1f GB", b/1073741824}'
  elif [ "$b" -ge 1048576 ]; then
    awk -v b="$b" 'BEGIN {printf "%.1f MB", b/1048576}'
  elif [ "$b" -ge 1024 ]; then
    awk -v b="$b" 'BEGIN {printf "%.1f KB", b/1024}'
  else
    printf "%d B" "$b"
  fi
}

# Parse human-readable size string (e.g. 8.4M, 26G, 8.0K, 512B) to integer byte count
function parse_size_bytes() {
  local s="${1:-0}"
  if [ -z "$s" ] || [ "$s" == "null" ] || [ "$s" == "N/A" ] || [ "$s" == "Unknown" ]; then
    echo 0
    return
  fi
  s=$(echo "$s" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
  local num
  case "$s" in
    *T|*TB)
      num="${s%T*}"
      awk -v n="$num" 'BEGIN {printf "%.0f\n", n * 1099511627776}'
      ;;
    *G|*GB)
      num="${s%G*}"
      awk -v n="$num" 'BEGIN {printf "%.0f\n", n * 1073741824}'
      ;;
    *M|*MB)
      num="${s%M*}"
      awk -v n="$num" 'BEGIN {printf "%.0f\n", n * 1048576}'
      ;;
    *K|*KB)
      num="${s%K*}"
      awk -v n="$num" 'BEGIN {printf "%.0f\n", n * 1024}'
      ;;
    *B)
      num="${s%B}"
      awk -v n="$num" 'BEGIN {printf "%.0f\n", n}'
      ;;
    *)
      if [[ "$s" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        awk -v n="$s" 'BEGIN {printf "%.0f\n", n}'
      else
        echo 0
      fi
      ;;
  esac
}

# Display a styled empty-state or notification box
function draw_empty_box() {
  local msg="$1"
  local width="${2:-96}"
  local inner_width=$((width - 4))
  init_table_theme
  local seg
  seg=$(repeat_char "$((width - 2))" "$BOX_H")
  printf "${CLR_GRAY}%s%s%s${CLR_RESET}\n" "$BOX_TL" "$seg" "$BOX_TR"
  printf "${CLR_GRAY}%s${CLR_RESET} %-*s ${CLR_GRAY}%s${CLR_RESET}\n" "$BOX_V" "$inner_width" "$msg" "$BOX_V"
  printf "${CLR_GRAY}%s%s%s${CLR_RESET}\n" "$BOX_BL" "$seg" "$BOX_BR"
}
