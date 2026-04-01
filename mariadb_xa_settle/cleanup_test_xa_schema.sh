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
  
TABLE_EXISTS=$($CMD_MARIADB $CLOPTS -ABNe "select TABLE_NAME from information_schema.TABLES where TABLE_SCHEMA='test_xa' and TABLE_NAME='xa_table';")
SCHEMA_EXISTS=$($CMD_MARIADB $CLOPTS -ABNe "select SCHEMA_NAME from information_schema.SCHEMATA where SCHEMA_NAME='test_xa';")

if [ ! $SCHEMA_EXISTS ]; then echo "SCHEMA test_xa DOES NOT EXIST."; exit 0; fi

if [ $TABLE_EXISTS ]; then
  $CMD_MARIADB $CLOPTS -Ae "SET STATEMENT max_statement_time=3 FOR DELETE FROM test_xa.xa_table;" || ERR=true
  if [ $ERR ]; then die "Cannot get lock on rows of table test_xa.xa_table. There may be pending XA transactions."; fi
fi

$CMD_MARIADB $CLOPTS -Ae " select concat('DROPPING SCHEMA test_xa.') as NOTE; drop schema if exists test_xa" || ERR=true