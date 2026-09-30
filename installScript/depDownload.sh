#!/bin/bash
################################################################################

################################################################################
# install_ubuntu: Install all the dependencies in Ubuntu Server
################################################################################
function install_ubuntu() {
  echo "Installing dependencies. Please wait..."
  if ! which parallel >/dev/null 2>&1 || ! which sqlite3 >/dev/null 2>&1; then
    apt-get update -qq > /dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq parallel sqlite3 > /dev/null 2>&1
  fi
  if which parallel >/dev/null 2>&1; then
    echo "Dependencies verified with success!"
  else
    echo "Dependencies could not be installed automatically. Please run: apt install -y parallel sqlite3"
    exit "$ERR_DEPNOTFOUND"
  fi
}

################################################################################
# install_redhat: Install all the dependencies in Red Hat, Rocky, Alma and CentOS
################################################################################
function install_redhat() {
  echo "Installing dependencies. Please wait..."
  local PKG_MGR="yum"
  which dnf >/dev/null 2>&1 && PKG_MGR="dnf"
  if ! which parallel >/dev/null 2>&1 || ! which sqlite3 >/dev/null 2>&1; then
    $PKG_MGR install -y epel-release > /dev/null 2>&1 || true
    $PKG_MGR install -y parallel sqlite > /dev/null 2>&1
  fi
  if which parallel >/dev/null 2>&1; then
    echo "Dependencies verified with success!"
  else
    echo "Dependencies could not be installed automatically. Please run: $PKG_MGR install -y epel-release parallel sqlite"
    exit "$ERR_DEPNOTFOUND"
  fi
}

################################################################################
# remove_ubuntu: Remove all the dependencies in Ubuntu Server
################################################################################
function remove_ubuntu() {
  echo "Removing dependencies. Please wait..."
  apt --purge remove -y parallel > /dev/null 2>&1
  BASHERRCODE=$?
  if [[ $BASHERRCODE -eq 0 ]]; then
    echo "Dependencies removed with success!"
  else
    echo "Dependencies wasn't removed in your server"
    echo "Please check if you have connection with the internet and apt is"
    echo "working and try again."
    echo "Or you can try manual execute the command:"
    echo "apt remove -y parallel"
  fi
}

################################################################################
# remove_redhat: Install all the dependencies in Red Hat and CentOS
################################################################################
function remove_redhat() {
  echo "Removing dependencies. Please wait..."
  grep 6 /etc/redhat-release > /dev/null 2>&1
  BASHERRCODE=$?
  if [[ $BASHERRCODE -eq 0 ]]; then
    pip uninstall -y curl > /dev/null 2>&1
  fi
  yum remove -y parallel > /dev/null 2>&1
  BASHERRCODE=$?
  if [[ $BASHERRCODE -eq 0 ]]; then
    echo "Dependencies removed with success!"
  else
    echo "Dependencies wasn't removed in your server"
    echo "Please check if you have connection with the internet and yum is"
    echo "working and try again."
    echo "Or you can try manual execute the command:"
    echo "yum install -y epel-release && yum install -y parallel"
  fi
}
