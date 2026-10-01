#!/bin/bash
################################################################################
# Installation Checks & Environment Verification
################################################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=/dev/null
if [ -f "$PARENT_DIR/project/lib/bash/TableHelper.sh" ]; then
  source "$PARENT_DIR/project/lib/bash/TableHelper.sh"
elif [ -f "/usr/local/lib/cmbkp/bash/TableHelper.sh" ]; then
  source "/usr/local/lib/cmbkp/bash/TableHelper.sh"
elif [ -f "/usr/local/lib/cmbackup/bash/TableHelper.sh" ]; then
  source "/usr/local/lib/cmbackup/bash/TableHelper.sh"
fi

################################################################################
# check_env: Check the environment if everything is okay to begin the install
################################################################################
function check_env() {
  type init_table_theme &>/dev/null && init_table_theme

  printf "  %-32s" "Root Privileges..."
  if [ "$(id -u)" -ne 0 ]; then
    printf "%b[NO ROOT]%b\n" "${CLR_BOLD_RED:-}" "${CLR_RESET:-}"
    echo "You need root privileges to install cmbkp"
    exit "$ERR_NOROOT"
  else
    printf "%b[ROOT]%b\n" "${CLR_BOLD_GREEN:-}" "${CLR_RESET:-}"
  fi

  printf "  %-32s" "Cmbkp / Cmbackup Install..."
  su -s /bin/bash -c "which cmbkp || which cmbackup" "$OSE_USER" > /dev/null 2>&1
  BASHERRCODE=$?
  if [ $BASHERRCODE != 0 ]; then
    printf "%b[NEW INSTALL]%b\n" "${CLR_CYAN:-}" "${CLR_RESET:-}"
    export UPGRADE="N"
    export UNINSTALL="N"
  elif [[ $1 == '--remove' ]] || [[ $1 == '-r' ]]; then
    printf "%b[UNINSTALL]%b - Executing uninstall routine\n" "${CLR_BOLD_YELLOW:-}" "${CLR_RESET:-}"
    export UPGRADE="N"
    export UNINSTALL="Y"
  else
    VERSION=$(su -s /bin/bash -c "cmbkp -v 2>/dev/null || cmbackup -v 2>/dev/null" "$OSE_USER")
    if [[ "$VERSION" != "$ZMBKP_VERSION" ]] || [[ "$1" == '--force-upgrade' ]] || [[ "$1" == '--upgrade' ]] || [[ "$1" == '-u' ]]; then
      printf "%b[UPGRADE]%b - Upgrading %s to %s\n" "${CLR_BOLD_YELLOW:-}" "${CLR_RESET:-}" "${VERSION:-older cmbackup}" "$ZMBKP_VERSION"
      export UPGRADE="Y"
      export UNINSTALL="N"
    else
      printf "%b[LATEST]%b - %s is already installed\n" "${CLR_BOLD_GREEN:-}" "${CLR_RESET:-}" "$ZMBKP_VERSION"
      export UPGRADE="Y"
      export UNINSTALL="N"
    fi
  fi

  printf "  %-32s" "Checking OS..."
  which apt > /dev/null 2>&1
  BASHERRCODE=$?
  if [[ $BASHERRCODE -eq 0 ]]; then
    printf "%b[UBUNTU SERVER]%b\n" "${CLR_BOLD_GREEN:-}" "${CLR_RESET:-}"
    SO="ubuntu"
  fi
  which yum > /dev/null 2>&1
  BASHERRCODE=$?
  if [[ $BASHERRCODE -eq 0 ]]; then
    printf "%b[RED HAT ENTERPRISE LINUX]%b\n" "${CLR_BOLD_GREEN:-}" "${CLR_RESET:-}"
    SO="redhat"
  elif [[ -z $SO ]]; then
    printf "%b[UNSUPPORTED]%b\n" "${CLR_BOLD_RED:-}" "${CLR_RESET:-}"
    exit 1
  fi
}

################################################################################
# check_config: Check the environment for other configurations
################################################################################
function check_config() {
  type init_table_theme &>/dev/null && init_table_theme

  local masked_pass="********"
  [ -z "$OSE_INSTALL_LDAPPASS" ] && masked_pass="(none)"

  local widths=(36 57)
  echo ""
  printf "  %b%s%b\n" "${CLR_BOLD_CYAN:-}" "Installation Configuration Summary" "${CLR_RESET:-}"
  draw_table_border top "${widths[@]}"
  printf "%b%s%b %b%-34s%b %b%s%b %b%-55s%b %b%s%b\n" \
    "${CLR_GRAY:-}" "$BOX_V" "${CLR_RESET:-}" "${CLR_BOLD_CYAN:-}" "Parameter" "${CLR_RESET:-}" \
    "${CLR_GRAY:-}" "$BOX_V" "${CLR_RESET:-}" "${CLR_BOLD_CYAN:-}" "Value" "${CLR_RESET:-}" \
    "${CLR_GRAY:-}" "$BOX_V" "${CLR_RESET:-}"
  draw_table_border mid "${widths[@]}"

  local params=(
    "Carbonio User"               "$OSE_USER"
    "Carbonio IP Address"         "$OSE_INSTALL_ADDRESS"
    "Carbonio LDAP Password"      "$masked_pass"
    "Carbonio Install Directory"  "$OSE_INSTALL_DIR"
    "Carbonio Backup Directory"   "$OSE_DEFAULT_BKP_DIR"
    "Cmbackup Install Directory"  "$ZMBKP_SRC"
    "Cmbackup Settings Directory" "$ZMBKP_CONF"
    "Cmbackup Retention Days"     "$ROTATE_TIME"
    "Cmbackup Parallel Workers"   "$MAX_PARALLEL_PROCESS"
    "Cmbackup Daily Lock"         "$LOCK_BACKUP"
    "Cmbackup Session Storage"    "$SESSION_TYPE"
  )

  for ((i=0; i<${#params[@]}; i+=2)); do
    local key="${params[i]}"
    local val="${params[i+1]}"
    printf "%b%s%b %b%-34s%b %b%s%b %b%-55s%b %b%s%b\n" \
      "${CLR_GRAY:-}" "$BOX_V" "${CLR_RESET:-}" "${CLR_BOLD_WHITE:-}" "$key" "${CLR_RESET:-}" \
      "${CLR_GRAY:-}" "$BOX_V" "${CLR_RESET:-}" "${CLR_GREEN:-}" "$val" "${CLR_RESET:-}" \
      "${CLR_GRAY:-}" "$BOX_V" "${CLR_RESET:-}"
  done

  draw_table_border bot "${widths[@]}"
  echo ""
  if [ "${UNATTENDED:-}" == "true" ]; then
    echo "Unattended mode: proceeding with installation."
  else
    echo "Press ENTER to continue or CTRL+C to cancel."
    read -r
  fi
}
