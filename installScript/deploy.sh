#!/bin/bash
################################################################################

################################################################################
# blocklist_gen: Generate a blocked list of all accounts Cmbackup should ignore
################################################################################
function blocklist_gen(){
  for ACCOUNT in $(sudo -H -u "$OSE_USER" bash -c "/opt/zextras/bin/zmprov -l gaa"); do
    if  [[ "$ACCOUNT" = "galsync"* ]] || \
    [[ "$ACCOUNT" = "virus"* ]] || \
    [[ "$ACCOUNT" = "ham"* ]] || \
    [[ "$ACCOUNT" = "zextras"* ]] || \
    [[ "$ACCOUNT" = "spam"* ]] || \
    [[ "$ACCOUNT" = "cmbackup"* ]] || \
    [[ "$ACCOUNT" = "postmaster"* ]] || \
    [[ "$ACCOUNT" = "root"* ]]; then
      echo "$ACCOUNT" >> "$ZMBKP_CONF"/blockedlist.conf
    fi
  done
}

################################################################################
# deploy_new: Deploy a new version of Cmbackup
################################################################################
function deploy_new() {
  echo "Installing... Please wait while we made some changes."
  echo -ne '                      (0%)\r'
  mkdir -p "$OSE_DEFAULT_BKP_DIR" > /dev/null 2>&1
  BASHERRCODE=$?
  if [[ $BASHERRCODE -ne 0 ]]; then
        echo "[FAIL] - Can't create the directory"
        echo "For some reason the Cmbackup can't create the folder $OSE_DEFAULT_BKP_DIR."
	echo "Maybe you are using a NFS and the permissions are wrong?"
	echo "Please check what happened and try again."
	uninstall
	exit "$ERR_DEPNOTFOUND"
  fi

  if [[ $SESSION_TYPE == "TXT" ]]; then
    touch "$OSE_DEFAULT_BKP_DIR"/sessions.txt
  elif [[ $SESSION_TYPE == "SQLITE3" ]]; then
    sqlite3 "$OSE_DEFAULT_BKP_DIR"/sessions.sqlite3 < project/lib/sqlite3/database.sql > /dev/null 2>&1
  fi
  chown -R "$OSE_USER"."$OSE_USER" "$OSE_DEFAULT_BKP_DIR" > /dev/null 2>&1
  echo -ne '#                     (5%)\r'
  test -d "$ZMBKP_CONF" || mkdir -p "$ZMBKP_CONF"
  echo -ne '##                    (10%)\r'
  test -d "$ZMBKP_SRC"  || mkdir -p "$ZMBKP_SRC"
  echo -ne '###                   (15%)\r'
  test -d "$ZMBKP_SHARE" || mkdir -p "$ZMBKP_SHARE"
  test -d "$ZMBKP_LIB" || mkdir -p "$ZMBKP_LIB"
  echo -ne '####                  (20%)\r'

  # Disable Parallel's message - Cmbackup remind the user about GNU Parallel
  mkdir -p "$OSE_INSTALL_DIR"/.parallel > /dev/null 2>&1 && touch "$OSE_INSTALL_DIR"/.parallel/will-cite
  chown -R "$OSE_USER":"$OSE_USER" "$OSE_INSTALL_DIR"/.parallel

  # Copy binary and setup alias symlink
  install -o "$OSE_USER" -g "$OSE_USER" -m 755 "$MYDIR"/project/cmbkp "$ZMBKP_SRC"/cmbkp
  ln -sf "$ZMBKP_SRC"/cmbkp "$ZMBKP_SRC"/cmbackup
  echo -ne '#####                 (25%)\r'
  cp -R "$MYDIR"/project/lib/* "$ZMBKP_LIB"
  chown -R "$OSE_USER":"$OSE_USER" "$ZMBKP_LIB"
  chmod -R 755 "$ZMBKP_LIB"
  echo -ne '######                (30%)\r'

  # Directory symlinks for backward compatibility
  [ "$ZMBKP_LIB" != "/usr/local/lib/cmbackup" ] && ln -sfn "$ZMBKP_LIB" /usr/local/lib/cmbackup
  [ "$ZMBKP_CONF" != "/etc/cmbackup" ] && ln -sfn "$ZMBKP_CONF" /etc/cmbackup

  # Shell alias for cmbackup -> cmbkp
  echo "alias cmbackup='cmbkp'" > /etc/profile.d/cmbkp.sh
  chmod 644 /etc/profile.d/cmbkp.sh

  install --backup=numbered -o root -m 600 "$MYDIR"/project/config/cmbkp.cron /etc/cron.d/cmbkp
  [ -f /etc/cron.d/cmbackup ] && rm -f /etc/cron.d/cmbackup
  echo -ne '#######               (35%)\r'
  install --backup=numbered -o "$OSE_USER" -m 600 "$MYDIR"/project/config/cmbkp.conf "$ZMBKP_CONF"/cmbkp.conf
  ln -sf "$ZMBKP_CONF"/cmbkp.conf "$ZMBKP_CONF"/cmbackup.conf
  echo -ne '########              (40%)\r'
  install --backup=numbered -o "$OSE_USER" -m 600 "$MYDIR"/project/config/blockedlist.conf "$ZMBKP_CONF"
  echo -ne '#########             (45%)\r'

  # Including custom settings
  for cfg in "$ZMBKP_CONF"/cmbkp.conf; do
    sed -i "s|{OSE_DEFAULT_BKP_DIR}|${OSE_DEFAULT_BKP_DIR}|g" "$cfg"
    sed -i "s|{ZMBKP_MAIL_ALERT}|${ZMBKP_MAIL_ALERT}|g" "$cfg"
    sed -i "s|{ZMBKP_MAIL_SENDER}|${ZMBKP_MAIL_SENDER}|g" "$cfg"
    sed -i "s|{OSE_INSTALL_ADDRESS}|${OSE_INSTALL_ADDRESS}|g" "$cfg"
    sed -i "s|{OSE_INSTALL_LDAPPASS}|${OSE_INSTALL_LDAPPASS}|g" "$cfg"
    sed -i "s|{SESSION_TYPE}|${SESSION_TYPE}|g" "$cfg"
    sed -i "s|{OSE_USER}|${OSE_USER}|g" "$cfg"
    sed -i "s|{MAX_PARALLEL_PROCESS}|${MAX_PARALLEL_PROCESS}|g" "$cfg"
    sed -i "s|{ROTATE_TIME}|${ROTATE_TIME}|g" "$cfg"
    sed -i "s|{LOCK_BACKUP}|${LOCK_BACKUP}|g" "$cfg"
  done
  echo -ne '#################     (85%)\r'

  # Fix backup dir permissions (owner MUST be $OSE_USER)
  chown "$OSE_USER" "$OSE_DEFAULT_BKP_DIR"
  echo -ne '##################    (90%)\r'

  # Generate Cmbackup's blocked list
  blocklist_gen

  echo -ne '####################  (100%)\r'
}

################################################################################
# deploy_upgrade: Upgrade the old version to the new one
################################################################################
function deploy_upgrade(){
  # Removing old version
  echo "Upgrading... Please wait while we made some changes."
  echo -ne '                     (0%)\r'
  rm -rf "$ZMBKP_SHARE" "$ZMBKP_SRC"/zmbhousekeep > /dev/null 2>&1
  echo -ne '##########            (50%)\r'

  # Disable Parallel's message - Cmbackup remind the user about GNU Parallel
  mkdir -p "$OSE_INSTALL_DIR"/.parallel > /dev/null 2>&1 && touch "$OSE_INSTALL_DIR"/.parallel/will-cite
  chown -R "$OSE_USER":"$OSE_USER" "$OSE_INSTALL_DIR"/.parallel

  # Copy binary and setup alias symlink
  install -o "$OSE_USER" -g "$OSE_USER" -m 755 "$MYDIR"/project/cmbkp "$ZMBKP_SRC"/cmbkp
  ln -sf "$ZMBKP_SRC"/cmbkp "$ZMBKP_SRC"/cmbackup
  echo -ne '###############       (75%)\r'
  test -d "$ZMBKP_LIB" || mkdir -p "$ZMBKP_LIB"
  cp -R "$MYDIR"/project/lib/* "$ZMBKP_LIB"
  chown -R "$OSE_USER":"$OSE_USER" "$ZMBKP_LIB"
  chmod -R 755 "$ZMBKP_LIB"
  [ "$ZMBKP_LIB" != "/usr/local/lib/cmbackup" ] && ln -sfn "$ZMBKP_LIB" /usr/local/lib/cmbackup
  if [ -d "/etc/cmbackup" ] && [ ! -L "/etc/cmbackup" ]; then
    if [ ! -d "$ZMBKP_CONF" ]; then
      mv /etc/cmbackup "$ZMBKP_CONF"
    else
      cp -rn /etc/cmbackup/* "$ZMBKP_CONF"/ 2>/dev/null || true
      rm -rf /etc/cmbackup
    fi
    ln -sfn "$ZMBKP_CONF" /etc/cmbackup
  fi
  test -d "$ZMBKP_CONF" || mkdir -p "$ZMBKP_CONF"
  [ ! -f "$ZMBKP_CONF/cmbkp.conf" ] && [ -f "$ZMBKP_CONF/cmbackup.conf" ] && ln -sf "$ZMBKP_CONF/cmbackup.conf" "$ZMBKP_CONF/cmbkp.conf"
  [ ! -f "$ZMBKP_CONF/cmbackup.conf" ] && [ -f "$ZMBKP_CONF/cmbkp.conf" ] && ln -sf "$ZMBKP_CONF/cmbkp.conf" "$ZMBKP_CONF/cmbackup.conf"
  [ "$ZMBKP_CONF" != "/etc/cmbackup" ] && [ ! -L "/etc/cmbackup" ] && ln -sfn "$ZMBKP_CONF" /etc/cmbackup
  echo "alias cmbackup='cmbkp'" > /etc/profile.d/cmbkp.sh
  chmod 644 /etc/profile.d/cmbkp.sh
  echo -ne '####################  (100%)\r'
}

################################################################################
# uninstall: Remove cmbackup, their dependencies, and all files related
################################################################################
function uninstall() {
  echo "Removing... Please wait while we made some changes."
  [ -f "$ZMBKP_CONF"/cmbkp.conf ] && source "$ZMBKP_CONF"/cmbkp.conf
  [ -f "$ZMBKP_CONF"/cmbackup.conf ] && source "$ZMBKP_CONF"/cmbackup.conf
  echo -ne '                     (0%)\r'
  rm -rf "$ZMBKP_SHARE" "$ZMBKP_SRC"/zmbhousekeep > /dev/null 2>&1
  rm -rf "$OSE_INSTALL_DIR"/.parallel
  echo -ne '#####                 (25%)\r'
  rm -rf /etc/yum.repos.d/tange.repo
  rm -rf /etc/cron.d/cmbackup /etc/cron.d/cmbkp /etc/profile.d/cmbkp.sh
  rm -rf "$ZMBKP_LIB" "$ZMBKP_CONF" "$ZMBKP_SRC"/cmbackup "$ZMBKP_SRC"/cmbkp /etc/cmbackup /usr/local/lib/cmbackup
  echo -ne '##########            (50%)\r'
  if [[ -f $ZMBKP_CONF/blockedlist.conf ]]; then
    install --backup=numbered -o "$OSE_USER" -m 600 "$MYDIR"/project/config/blockedlist.conf "$ZMBKP_CONF"
    blocklist_gen
  fi
  echo -ne '####################  (100%)\r'
  printf "Preserve Backup Storage?[n/Y]"
  read -r OPT
  if [[ $OPT == 'N' && $OPT == 'n' ]]; then
    echo "Removing backup storage..."
    rm -rf "${WORKDIR:?}"/*
  fi
}
