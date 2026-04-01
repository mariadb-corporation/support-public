#!/usr/bin/env bash
# test_setup_xa_settle.sh
# file distributed with mariadb_xa_settle
# By Edward Stoever for MariaDB Support

# REF 206295, 206801


# Establish working directory and source pre_quick_review.sh
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source ${SCRIPT_DIR}/vsn.sh

TEMPDIR="/tmp"
CONFIG_FILE="$SCRIPT_DIR/xa_settle.cnf"
SQL_DIR="$SCRIPT_DIR/SQL"
TOOL="mariadb_xa_settle"
SQL_FILE=$SQL_DIR/TEST_SETUP.sql
RUN_THIS_MANY_TIMES=5 # HOW MANY INSERTS WILL BE XA PREPARED, NOT XA COMMIT

function ts() {
   TS=$(date +%F-%T | tr ':-' '_')
   echo "$TS $*"
}

function die() {
   ts "$*" >&2
   exit 1
}

function _which() {
   if [ -x /usr/bin/which ]; then
      /usr/bin/which "$1" 2>/dev/null | awk '{print $1}'
   elif which which 1>/dev/null 2>&1; then
      which "$1" 2>/dev/null | awk '{print $1}'
   else
      echo "$1"
   fi
}

if [ $(_which mariadb 2>/dev/null) ]; then
  CMD_MARIADB="${CMD_MARIADB:-"$(_which mariadb)"}"
else
  CMD_MARIADB="${CMD_MYSQL:-"$(_which mysql)"}"
fi

CMD_MY_PRINT_DEFAULTS="${CMD_MY_PRINT_DEFAULTS:-"$(_which my_print_defaults)"}"
CLOPTS=$($CMD_MY_PRINT_DEFAULTS --defaults-file=$CONFIG_FILE mariadb_xa_settle | sed -z -e "s/\n/ /g")

if [ -z $CMD_MARIADB ]; then
  die "mariadb client command not available."
fi

if [ -z $CMD_MY_PRINT_DEFAULTS ]; then
  die "my_print_defaults command not available."
fi

  CONNECTING_AS=$($CMD_MARIADB $CLOPTS -ABNe "select user();") || ERR=true
  if [ $ERR ]; then die "Something went wrong (CONNECTING_AS)!";  fi 
  echo "Connecting as user $CONNECTING_AS."

for ((n=0;n<${RUN_THIS_MANY_TIMES};n++)); do

  export ATR1=$($CMD_MARIADB $CLOPTS -ABNe "select concat('000000000000000000',FLOOR(111111111 + RAND() * (999999999 - 111111111 + 1)),'quarkedw')") || ERR=true
  export ATR2=$($CMD_MARIADB $CLOPTS -ABNe "select concat('000000000000000000',FLOOR(111111111 + RAND() * (999999999 - 111111111 + 1)),'policarpa');") || ERR=true
  export ATR3=$($CMD_MARIADB $CLOPTS -ABNe "select FLOOR(111111 + RAND() * (999999 - 111111 + 1))") || ERR=true

  SQL=$(envsubst < $SQL_FILE)

  $CMD_MARIADB $CLOPTS -e "$SQL"  || ERR=true
  
  if [ $ERR ]; then die "Something went wrong!";  fi 
  
done

$CMD_MARIADB $CLOPTS -Ae "select concat('PREPARED XA TRANSACTIONS, NOT YET COMMIT.') as NOTE; xa recover format='SQL';"
