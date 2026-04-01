#!/usr/bin/env bash
# Script by Edward Stoever for Mariadb Support
# REF: CS0725679
# Iterate through files in DATADIR to find any files that are corrupted using innochecksum.

# OUTPUT SAMPLE:
# OK      /var/lib/mysql/CS0725679/tbl_menu.ibd
# BAD!!   /var/lib/mysql/CS0725679/xyz.ibd
# OK      /var/lib/mysql/student_db/std_admissions_schools.ibd
# OK      /var/lib/mysql/student_db/another_t.ibd

# VERIFY THIS IS A MARIADB SERVER BY ENSURING my_print_defaults IS IN PATH.
if [ ! $(which my_print_defaults) ]; then echo "This host does not have my_print_defaults command in PATH. Is this a Mariadb database server?"; exit 1; fi

# LOOK FOR VALUE OF DATADIR IN .cnf OPTIONS FILES:
DATADIR=$(my_print_defaults --mysqld| grep -i datadir | tail -1 | cut -d '=' -f2 | xargs)

# IF DATADIR IS NOT DEFINED IN .cnf OPTIONS FILE, THEN IT SHOULD BE DEFAULT VALUE:
if [ ! $DATADIR ]; then DATADIR="/var/lib/mysql"; fi

if [ ! -f ${DATADIR}/ibdata1 ]; then 
  printf "Edit this file and define the correct value for DATADIR.\n"
  exit 1
fi

find ${DATADIR} -type f \( -name "ibdata1" -o -name "ibtmp1" -o -name "*.ibd" \) -exec bash -c 'innochecksum "$0" 1>/dev/null 2>/dev/null && printf "OK    " || printf "BAD!! "; printf "  $0\n"' {} \;

