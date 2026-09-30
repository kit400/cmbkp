#!/bin/bash
################################################################################
# install - Install script to help you install cmbackup in your server. You can
#           simply ignore this file and move the files to the correctly place, but
#           the chance for this goes wrong is big. So, this script made everything
#           for you easy.
#
################################################################################
# INSTALL MAIN CODE
################################################################################

#
#  Help code
################################################################################
if [[ $1 == "--help" ]] || [[ $1 == "-h" ]]; then
  show_help
  exit "$ERR_OK"
fi

################################################################################
# LOADING INSTALL LIBRARIES
################################################################################
echo "Loading installer - PLEASE WAIT"
source installScript/check.sh
source installScript/depDownload.sh
source installScript/deploy.sh
source installScript/menu.sh
source installScript/vars.sh
source installScript/help.sh

#
#  Checking your environment
################################################################################
check_env "$1"

#
#  Uninstall code
################################################################################
if [[ $1 == "--remove" ]] || [[ $1 == "-r" ]]; then
  if [[ $UNINSTALL = "Y" ]]; then
    if [[ $SO = "ubuntu" ]]; then
      echo "Disabled Package Uninstall"
      # remove_ubuntu
    else
      echo "Disabled Package Uninstall"
      # remove_redhat
    fi
    uninstall
    echo "Uninstall completed. Thanks for using Cmbackup. Have a nice day!"
    exit "$ERR_OK"
  else
    echo "Cmbackup is not installed - nothing to do"
    exit "$ERR_OK"
  fi
fi

UNATTENDED="N"
for arg in "$@"; do
  if [[ "$arg" == "-y" ]] || [[ "$arg" == "--yes" ]] || [[ "$arg" == "--unattended" ]]; then
    UNATTENDED="Y"
  fi
done

#
# Install & Upgrade code
################################################################################
if [[ $UNATTENDED != "Y" ]]; then
  contract
fi

if [[ $UPGRADE = "Y" ]]; then
  if [[ $SO = "ubuntu" ]]; then
    install_ubuntu
  else
    install_redhat
  fi
  deploy_upgrade
else
  if [[ $UNATTENDED != "Y" ]]; then
    set_values
    check_config
  fi
  if [[ $SO = "ubuntu" ]]; then
    install_ubuntu
  else
    install_redhat
  fi
  deploy_new
fi

# We're done!
if [[ $UNATTENDED != "Y" ]]; then
  read -r -p "Install completed. Do you want to display the README file? (Y/n)" tmp
  case "$tmp" in
  	y|Y|Yes|"") less "$MYDIR"/README.md;;
  	*) echo "Done!";;
  esac
  clear
else
  echo "Installation completed successfully."
fi

exit "$ERR_OK"
