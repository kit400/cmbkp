#!/bin/bash
################################################################################
# SET INTERNAL VARIABLE
################################################################################

# Exit codes
ERR_OK="0"  		         # No error (normal exit)
ERR_NOBKPDIR="1"  	     # No backup directory could be found
ERR_NOROOT="2"  		     # Running without root privileges
ERR_DEPNOTFOUND="3"  	   # Missing dependency
ERR_NO_CONNECTION="4"    # Missing connection to install packages
ERR_CREATE_USER="5"      # Can't create the user for some reason

# CMBACKUP INSTALLATION PATH
MYDIR=`dirname $0`                       # The directory where the install script is
ZMBKP_SRC="/usr/local/bin"               # The main script stay here
ZMBKP_CONF="/etc/cmbackup"               # The config/blocked list directory
ZMBKP_SHARE="/usr/local/share/cmbackup"  # Keep for upgrade routine
ZMBKP_LIB="/usr/local/lib/cmbackup"      # The new path for the libs

# ZIMBRA DEFAULT INSTALLATION PATH AND INTERNAL CONFIGURATION
OSE_USER="zextras"                                                                                                                             # Carbonio's unix user
OSE_INSTALL_DIR="/opt/zextras"                                                                                                                 # The Carbonio's installation path
OSE_DEFAULT_BKP_DIR="/opt/zextras/backup"                                                                                                      # Where you will store your backup
OSE_INSTALL_DOMAIN=$(su -s /bin/bash -c "$OSE_INSTALL_DIR/bin/zmprov gad 2>/dev/null | head -1" "$OSE_USER" || echo "localdomain.com")
OSE_INSTALL_HOSTNAME=$(hostname --fqdn 2>/dev/null || hostname)
if [ -f "$OSE_INSTALL_DIR/conf/attrs/attrs.xml" ]; then
  OSE_INSTALL_PORT=$(grep -A1 zimbraAdminPort "$OSE_INSTALL_DIR/conf/attrs/attrs.xml" 2>/dev/null | grep globalConfigValue | grep -v zimbraAdminPort | cut -d\> -f2 | cut -d\< -f1)
fi
[ -z "$OSE_INSTALL_PORT" ] && OSE_INSTALL_PORT="7071"
OSE_INSTALL_ADDRESS=$(hostname -I 2>/dev/null | awk '{print $1}')
[ -z "$OSE_INSTALL_ADDRESS" ] && OSE_INSTALL_ADDRESS="127.0.0.1"
OSE_INSTALL_LDAPPASS=$(su -s /bin/bash -c "$OSE_INSTALL_DIR/bin/zmlocalconfig -s zimbra_ldap_password 2>/dev/null" "$OSE_USER" | awk '{print $3}')
ZMBKP_MAIL_ALERT="zextras@${OSE_INSTALL_DOMAIN}"
ZMBKP_MAIL_SENDER="cmbackup@${OSE_INSTALL_DOMAIN}"
MAX_PARALLEL_PROCESS="3"                                                                                                                       # Cmbackup's number of threads
ROTATE_TIME="30"                                                                                                                               # Cmbackup's max of days before housekeeper
LOCK_BACKUP=true                                                                                                                               # Cmbackup's backup lock
ZMBKP_VERSION="cmbackup version: 1.3.0"                                                                                                        # Cmbackup's latest version
SESSION_TYPE="TXT"                                                                                                                             # Cmbackup's default session type

# Force a terminal type - Issue #90
export TERM="linux"
