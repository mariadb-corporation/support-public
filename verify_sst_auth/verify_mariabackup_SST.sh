#!/bin/bash
# Script by Edward Stoever for Mariadb Support

# verify user account for mariabackup SST 
# Should return:
# --wsrep_sst_method=mariabackup --wsrep_sst_auth=mariabackup:password
# mariabackup:password
# +----------------+
# | PRIVILEGE_TYPE |
# +----------------+
# | RELOAD         |
# | PROCESS        |
# | LOCK TABLES    |
# | BINLOG MONITOR |
# +----------------+
unset ERR
cp privileges_check.sql /tmp/
chmod 644 /tmp/privileges_check.sql

echo $(my_print_defaults --mysqld | grep wsrep_sst)
MY_USER=$(my_print_defaults --mysqld| grep wsrep_sst_auth | tail -1 | sed 's/[^,=]*=//g'|cut -d: -f1)
MY_PW=$(my_print_defaults --mysqld| grep wsrep_sst_auth | tail -1 | sed 's/[^,=]*=//g'|cut -d: -f2)
if [ ! ${MY_USER} ]; then echo "The global wsrep_sst_auth is not in the configuration files."; exit 1; fi


if  [ ! ${MY_PW} ]; then 
  echo "A password for user ${MY_USER} is not set. Assuming unix_socket authentication for user ${MY_USER}."; 
else
  echo "$MY_USER:$MY_PW"
fi

if [ ! ${MY_PW} ]; then
  su - ${MY_USER} -c 'mariadb -Ae "select 1;"' 1>/dev/null 2>&1 || ERR=TRUE
  if [ $ERR ]; then echo "User ${MY_USER} cannot login to the database or cannot switch user to ${MY_USER}."; exit 1; fi
  su - ${MY_USER} -c 'mariadb  -v -v -v < /tmp/privileges_check.sql' | grep -E "(^\+\-|^\|)"
else
  mariadb -u "$MY_USER" -p"$MY_PW" -Ae "select 1;" 1>/dev/null 2>&1 || ERR=TRUE
  if [ $ERR ]; then echo "User ${MY_USER} cannot login to the database."; exit 1; fi
  mariadb -u "$MY_USER" -p"$MY_PW" -v -v -v < /tmp/privileges_check.sql | grep -E "(^\+\-|^\|)"
fi
