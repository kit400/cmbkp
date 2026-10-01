#!/bin/bash
################################################################################
# Miscellaneous Functions
################################################################################
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -f "$LIB_DIR/TableHelper.sh" ] && source "$LIB_DIR/TableHelper.sh"

################################################################################
# clear_temp: Clear all the temporary files.
################################################################################
function on_exit(){
  BASHERRCODE=$?
  if [[ -n $STYPE ]]; then
    if [[ $BASHERRCODE -eq 1 ]]; then
      notify_finish "$SESSION" "$STYPE" "FAILURE"
    elif [[ $BASHERRCODE -eq 0 && -n $SESSION ]]; then
      notify_finish "$SESSION" "$STYPE" "SUCCESS"
    fi
  fi
  # shellcheck disable=SC2086
  rm -rf "$TEMPSESSION" "$TEMPACCOUNT" "$TEMPINACCOUNT" "$TEMPDIR" $MESSAGE $TEMPSQL $FAILURE
  logger -i -p local7.info "Cmbackup: Excluding the temporary files before close."
}

#trap the function to be executed if the sript die
trap on_exit TERM INT EXIT

################################################################################
# create_temp: Create the temporary files used by the script.
################################################################################
function create_temp(){
  export readonly TEMPDIR
  export readonly TEMPACCOUNT
  export readonly TEMPINACCOUNT
  export readonly MESSAGE
  export readonly FAILURE
  export readonly TEMPSESSION
  export readonly TEMPSQL

  TEMPDIR=$(mktemp -d "$WORKDIR"/XXXX)
  TEMPACCOUNT=$(mktemp)
  TEMPINACCOUNT=$(mktemp)
  MESSAGE=$(mktemp)
  FAILURE=$(mktemp)
  TEMPSESSION=$(mktemp)
  TEMPSQL=$(mktemp)
}

if [[ ":$PATH:" != *":/opt/zextras/bin:"* ]]; then
  export PATH="/opt/zextras/bin:/opt/zextras/common/bin:$PATH"
fi

################################################################################
# load_config: Load the config file and zextras's bashrc.
################################################################################
function load_config(){
  if [ -n "$CMBACKUP_CONF" ] && [ -f "$CMBACKUP_CONF" ]; then
    source "$CMBACKUP_CONF" 2> /dev/null
  elif [ -f "/etc/cmbackup/cmbackup.conf" ]; then
    source /etc/cmbackup/cmbackup.conf 2> /dev/null
  elif [ -f "$(dirname "${BASH_SOURCE[0]}")/../../config/cmbackup.conf" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../../config/cmbackup.conf" 2> /dev/null
  else
    logger -i -p local7.err "Cmbackup: cmbackup.conf not found."
    echo "ERROR - cmbackup.conf not found. Can't proceed without the file."
    exit 1
  fi
  if [ -f "/opt/zextras/.bashrc" ]; then
    source /opt/zextras/.bashrc 2> /dev/null
  fi
}

################################################################################
# constants: Initialize all the constants used by the Cmbackup.
################################################################################
function constant(){
  # LDAP OBJECT
  if [ "$BACKUP_INACTIVE_ACCOUNTS" == "true" ]; then
    export readonly ACOBJECT="(objectclass=zimbraAccount)"
  else
    export readonly ACOBJECT="(&(objectclass=zimbraAccount)(zimbraAccountStatus=active))"
  fi

  # Enabling SSL for CMBACKUP
   if [ "$SSL_ENABLE" == "true" ]; then
     export readonly WEBPROTO="https"
   else
     export readonly WEBPROTO="http"
   fi

  export readonly DLOBJECT="(objectclass=zimbraDistributionList)"
  export readonly ALOBJECT="(objectclass=zimbraAlias)"
  export readonly SIOBJECT="(objectclass=zimbraSignature)"

  # LDAP FILTER
  export readonly DLFILTER="mail"
  export readonly ACFILTER="zimbraMailDeliveryAddress"
  export readonly ALFILTER="uid"
  export readonly SIFILTER="zimbraSignatureName"

  # PID FILE
  export readonly PID='/opt/zextras/log/cmbackup.pid'
}

################################################################################
# sessionvars: Initialize all the constants used by the backup action.
# Options:
#    $1 - The type of session that will be executed
#    $2 - OPTIONAL: Enable Incremental Backup
################################################################################
function sessionvars(){
  export readonly SESSION
  export readonly STYPE
  export readonly INC
  INC='FALSE'
  ls "$WORKDIR"/full* > /dev/null 2>&1
  ERRORCODE=$?
  if [[ $ERRORCODE -ne 0 || $1 == '--full' || $1 == '-f' ]]; then
    STYPE="Full Account"
    SESSION="full-"$(date  +%Y%m%d%H%M%S)
  elif [[ $1 == '--incremental' || $1 == '-i' ]]; then
    STYPE="Incremental Account"
    SESSION="inc-"$(date  +%Y%m%d%H%M%S)
    INC='TRUE'
  elif [[ $1 == '--alias' || $1 == '-al' ]]; then
    STYPE="Alias"
    SESSION="alias-"$(date  +%Y%m%d%H%M%S)
  elif [[ $1 == '-dl' || $1 == '--distributionlist' ]]; then
    STYPE="Distribution List"
    SESSION="distlist-"$(date  +%Y%m%d%H%M%S)
  elif [[ $1 == '-m' || $1 == '--mail' ]]; then
    STYPE="Mailbox"
    SESSION="mbox-"$(date  +%Y%m%d%H%M%S)
  elif [[ $1 == '--ldap' || $1 == '-ldp' ]]; then
    STYPE="Account - Only LDAP"
    SESSION="ldap-"$(date  +%Y%m%d%H%M%S)
  elif [[ $1 == '--signature' || $1 == '-sig' ]]; then
    STYPE="Signature"
    SESSION="signature-"$(date  +%Y%m%d%H%M%S)
  fi
}

################################################################################
# validate_config: Validate if all the values are informed and set the default if not
################################################################################
function validate_config(){

  ERR="false"

  if [ -z "$BACKUPUSER" ]; then
  	BACKUPUSER="zextras"
    logger -i -p local7.warn "Cmbackup: BACKUPUSER not informed - setting as user zextras instead."
  fi

  if [ "$(whoami)" != "$BACKUPUSER" ]; then
    echo "You need to be $BACKUPUSER to run this software."
    logger -i -p local7.err "Cmbackup: You need to be $BACKUPUSER to run this software."
    exit 2
  fi

  if [ -z "$WORKDIR" ]; then
    WORKDIR="/opt/zextras/backup"
    logger -i -p local7.warn "Cmbackup: WORKDIR not informed - setting as /opt/zextras/backup/ instead."
  fi

  if [ -z "$ENABLE_EMAIL_NOTIFY" ]; then
    ENABLE_EMAIL_NOTIFY="all"
    logger -i -p local7.warn "Cmbackup: ENABLE_EMAIL_NOTIFY not informed - setting as 'all' instead."
  fi

  if [ -z "$EMAIL_SENDER" ] || [ "$EMAIL_SENDER" == "root@" ]; then
    local_dom=$(hostname -d 2>/dev/null)
    [ -z "$local_dom" ] && local_dom="localhost"
    EMAIL_SENDER="cmbackup@$local_dom"
    logger -i -p local7.warn "Cmbackup: EMAIL_SENDER set as $EMAIL_SENDER"
  fi

  if [ -z "$EMAIL_NOTIFY" ]; then
    EMAIL_NOTIFY="root@localdomain.com"
    logger -i -p local7.warn "Cmbackup: EMAIL_NOTIFY not informed - setting as root@localdomain.com instead."
  fi

  if [ -z "$ZMMAILBOX" ] || [ ! -x "$ZMMAILBOX" ]; then
    if [ -x "/opt/zextras/bin/zmmailbox" ]; then
      ZMMAILBOX="/opt/zextras/bin/zmmailbox"
    else
      ZMMAILBOX=$(which zmmailbox 2>/dev/null)
    fi
    logger -i -p local7.warn "Cmbackup: ZMMAILBOX set as $ZMMAILBOX"
  fi

  if [ -z "$ZMMAILBOX_URL" ]; then
    ZMMAILBOX_URL="https://localhost:7071"
    logger -i -p local7.warn "Cmbackup: ZMMAILBOX_URL not defined - setting as $ZMMAILBOX_URL instead"
  fi

  if [ -z "$MAX_PARALLEL_PROCESS" ]; then
    MAX_PARALLEL_PROCESS="1"
    logger -i -p local7.warn "Cmbackup: MAX_PARALLEL_PROCESS not informed - disabling."
  fi

  if [ -z "$LOCK_BACKUP" ]; then
    LOCK_BACKUP=true
    logger -i -p local7.warn "Cmbackup: LOCK_BACKUP not informed - enabling."
  fi

  if ! [ -d "$WORKDIR" ]; then
    echo "The directory $WORKDIR doesn't exist."
    logger -i -p local7.err "Cmbackup: The directory $WORKDIR does not found."
    ERR="true"
  fi

  if [ -z "$LDAPSERVER" ]; then
    LDAP_URL=$(zmlocalconfig -s ldap_url 2>/dev/null | awk '{print $3}')
    if [ -n "$LDAP_URL" ]; then
      LDAPSERVER="$LDAP_URL"
    else
      LDAPSERVER="ldap://127.0.0.1:389"
    fi
    logger -i -p local7.info "Cmbackup: LDAPSERVER auto-detected as $LDAPSERVER"
  fi

  if [ -z "$LDAPADMIN" ]; then
    LDAP_DN=$(zmlocalconfig -s zimbra_ldap_userdn 2>/dev/null | awk '{print $3}')
    if [ -n "$LDAP_DN" ]; then
      LDAPADMIN="$LDAP_DN"
    else
      LDAPADMIN="uid=zimbra,cn=admins,cn=zimbra"
    fi
    logger -i -p local7.info "Cmbackup: LDAPADMIN auto-detected as $LDAPADMIN"
  fi

  if [ -z "$LDAPPASS" ]; then
    LDAP_PW=$(zmlocalconfig -s zimbra_ldap_password 2>/dev/null | awk '{print $3}')
    if [ -n "$LDAP_PW" ]; then
      LDAPPASS="$LDAP_PW"
      logger -i -p local7.info "Cmbackup: LDAPPASS auto-detected from localconfig"
    fi
  fi

  if [ -z "$ROTATE_TIME" ]; then
    ROTATE_TIME="30"
    logger -i -p local7.warn "Cmbackup: ROTATE_TIME not informed - setting to 30 days."
  fi

  if [ -z "$SESSION_TYPE" ]; then
    SESSION_TYPE="TXT"
    logger -i -p local7.warn "Cmbackup: SESSION_TYPE not informed - setting to TXT."
  fi

  if [ -z "$BACKUP_INACTIVE_ACCOUNTS" ]; then
    BACKUP_INACTIVE_ACCOUNTS="true"
    logger -i -p local7.warn "Cmbackup: BACKUP_INACTIVE_ACCOUNTS not informed - setting to true."
  fi

  if [ -z "$MIN_FREE_DISK_GB" ]; then
    MIN_FREE_DISK_GB="5"
  fi

  if [ -z "$SSL_ENABLE" ]; then
    echo "No value was found for SSL_ENABLE. Setting 'true' for the value."
    logger -i -p local7.warn "No value was found for SSL_ENABLE. Setting 'true' for the value."
  fi

  if [ "$ERR" == "true" ]; then
    echo "Some errors are found inside the config file. Please fix them and try again later."
    exit 3
  fi
}

################################################################################
# check_disk_space: Safeguard check on free disk space (from z2c)
################################################################################
function check_disk_space(){
  local target_dir="${1:-$WORKDIR}"
  local min_gb="${2:-$MIN_FREE_DISK_GB}"
  if [ -z "$min_gb" ]; then
    min_gb=5
  fi
  if [ -d "$target_dir" ]; then
    local free_kb
    free_kb=$(df -k "$target_dir" | tail -1 | awk '{print $4}')
    local free_gb=$(( free_kb / 1024 / 1024 ))
    if [ "$free_gb" -lt "$min_gb" ]; then
      echo "CRITICAL: Insufficient disk space on $target_dir: ${free_gb}GB available, minimum ${min_gb}GB required. Aborting to protect Carbonio services!"
      logger -i -p local7.err "Cmbackup: Insufficient disk space on $target_dir: ${free_gb}GB available, minimum ${min_gb}GB required. Aborting!"
      exit 6
    fi
  fi
}

################################################################################
# checkpid: Check if the PID file exist. If exist, exit with status 3 and do nothing
################################################################################
function checkpid(){
  if [[ -f "$PID" ]]; then
    PIDP=$(cat $PID)
    PIDR=$(ps -efa | awk '{print $2}' | grep -c "^$PIDP$")
    if [ "$PIDR" -gt 0 ]; then
      echo "FATAL: could not write lock file '/opt/zextras/log/cmbackup.pid': File already exist"
      echo "This file exist as a secure measurement to protect your system to run two cmbackup"
      echo "instances at the same time."
      exit 4
    else
      echo 'Found stale PID file. Proceeding'
      echo $$ > $PID
    fi
  else
    echo $$ > $PID
  fi
}

################################################################################
# export_function: Export all the functions used by ParallelAction
################################################################################
function export_function(){
  export -f __backupMailbox
  export -f __backupFullInc
  export -f __backupLdap
  export -f ldap_backup
  export -f ldap_restore
  export -f mailbox_backup
  export -f ldap_filter
  export -f mailbox_restore
  export -f check_disk_space
  export -f sort_accounts_by_size
  export -f verify_account_messages
  export -f audit_mailboxes
}

################################################################################
# export_vars: Export all the variables used by ParallelAction
################################################################################
function export_vars(){
  export LDAPSERVER
  export LDAPADMIN
  export LDAPPASS
  export WORKDIR
  export LOCK_BACKUP
  export SESSION_TYPE
  export MAILPORT
  export ZMMAILBOX
  export ZMMAILBOX_URL
  export MIN_FREE_DISK_GB
  export DRY_RUN
  export SINCE_DATE
}
