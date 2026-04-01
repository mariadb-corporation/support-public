#!/bin/bash
# Copyright (c) 2024 MariaDB plc. All rights reserved, proprietary and confidential.
# Unauthorized modification, copying or distribution is prohibited.
# MariaDB product terms at https://mariadb.com/product-terms-condition/ apply.
# This script is for the use by MariaDB and MariaDB subscription customers only.
# If you are not authorized to use this script, please delete this script from all devices under your control.
# Support at https://support.mariadb.com
# Contact person: Juan Vera Huneeus
#
# This script is a basic data gather for MariaDB Server in RHEL and Debian.
# List of supported operating systems at https://mariadb.com/engineering-policies/.
# 

ver='20250507.0'

echo "$(date) $0 $ver start on $(hostname)"
SECONDS=0
start=$(date +%s)

outDir="$HOME"
outHeader="mdbs-$caseno-$(hostname)-$(date +%Y%m%d)"
outFile="${outHeader}-sysinfo.out"

tStatusI=30	# time interval between global status reads
tErr=$(( $tStatusI * 6 ))	# timeout in seconds for queries that can stall due to performance issues combined with heavy schema or entity counts
tPasswordR=45	# time to wait for Password read prompt
rttCount=10	# total ping iterations for RTT in Galera clusters
logDays=30 # total number of days of log to retrieve - applies to error, slow, and syslog
inLineLimit=25 # Upper limit for number of rows of output for somme individual sections like processlist and binlog list. When this number is surpassed, these items are spooled out to their own files.
mlla=3	# MaxScale limit login attempts

hasSRV=0 #is a server installed here
isRunning=0	#is the server running
hasCLI=0	#do we have access to a mysql CLI
hasAccess=0	#can we get access to the server through the CLI

# Variables for command-line parameters
caseno=""
# MariaDB connection parameters
mdbu=""
mdbp=""
socket=""
ssl=""
skipssl=""
sslca=""
sslcapath=""
sslcert=""
sslcipher=""
sslkey=""

#MaxScale connection parameters
mxsu=""
mxsp=""
mxsP=""
secure=""
tlskey=""
tlspassphrase=""
tlscert=""
tlscacert=""

#Other parameters
debug=0
instanceonly=0
sysonly=0
maxonly=0
colonly=0

# Get the mariadb service executable name right away:
mdbd="$(which mariadbd 2>/dev/null)"
[ $? -ne 0 ] && mdbd="$(find / -name mariadbd)"
[ $? -ne 0 ] && mdbd="$(which mysqld 2>/dev/null)"
[ $? -ne 0 ] && mdbd="$(find / -name mysqld)"

usage() {
    echo "Usage: $0 --caseno <MariaDB Case Number> [--dir <$0 Output Directory>] [--mdbP <MariaDB Server Port>] [--mdbu <MariaDB Server User>] [--mdbp <MariaDB Server Password>] [--mxsu <MaxScale Admin User>] [--mxsp <MaxScale Admin Password>] [--sysonly] [--maxonly] [--colonly]" >&2
    echo >&2
    echo "For full help text type: $0 --help" >&2
    exit 1
}

helpText() {

	cat <<EOF | less
**                                        **
** press the 'q' key to quit this help    **
**                                        **
** the spacebar scrolls down one page     **
** ↓ j ↑ k scroll one line at a time      **
** g scrolls to the top, here             **
** G scrolls to the bottom of the text    **
**                                        **
** To search for a word, type a slash     **
** immediately followed by the string,    **
** like this:                             **
**     /MaxScale                          **

NAME
    mdb-support.sh - Collects MariaDB or MaxScale server information for diagnostics.

SYNOPSIS
    ./mdb-support.sh [OPTION]...

DESCRIPTION
    mdb-support.sh is a script that collects information from a MariaDB server or MaxScale instance
    to assist in troubleshooting. It safely gathers logas and global variables, server status, 
    etc without significantly affecting the server's load or memory usage.

    The script should be run in a root shell on the affected MariaDB or MaxScale server. It will prompt for the
    root or admin user password if necessary. For best results, run this script on a server that has
    been active for some time and, if possible, during a period of peak load.

OPTIONS
    --caseno CASENO
        Specify the related support ticket number. 6 or 7 digits.

    --dir TARGET-DIRECTORY
        Specify the location where support output files will be stored. Defaults to current user home directory.

    --logdays LOG-DAYS
        Specify the number of days of logs to collect. Defaults to 60 days.

    --mdbP MDBPort
    	Specify the configured listener port for MariaDB if different from the default 3306.

    --mdbu MDBUser
        Specify the MariaDB username if different from the current user "`whoami`".

    --mdbp MDBPassword
        Specify the MariaDB user's password. Use this option with caution as it exposes passwords
        in the shell's command history. In case the password has any special characters or spaces, 
        it can be quoted using single quotes like this: --mdbp 's#cr3t w0rd!'
        Quotes can be used interactively the same way.

    --socket path
        For MariaDB Server connections to localhost, the Unix socket file to use, or, on Windows, the name of the named pipe to use.  
        Forces --protocol=socket when specified on the command line without other connection properties; 
        on Windows, forces --protocol=pipe.

    --ssl
        Enable SSL for MariaDB Server connection (automatically enabled with other flags).
        
    --skip-ssl
        Disable SSL for MariaDB Server connection.

    --ssl-ca name
        MariaDB Server connection CA file in PEM format.

    --ssl-capath name
        MariaDB Server connection CA directory.

    --ssl-cert name
           MariaDB Server connection  X509 cert in PEM format.

    --ssl-cipher name
           MariaDB Server connection SSL cipher to use.

    --ssl-key name
           MariaDB Server connection X509 key in PEM format.

    --mxsu MXSUser
        Specify the MaxScale admin user name if different from the default "admin".

    --mxsp MXSPassword
        Specify the MaxScale admin user password if different from the default "mariadb".

    --mxsP MXSPort
    	Specify the configured admin port for Maxscale if different from the default 8989.
        
    --secure
        Enable HTTPS requests

    --tls-key
        Path to MaxScale TLS private key
        
    --tls-passphrase
        Password for the MaxScale TLS private key
        
    --tls-cert
        Path to MaxScale TLS public certificate 
        
    --tls-ca-cert
        Path to MaxScale TLS CA certificate
        
    --instanceonly
    	Collect only identifying instance information for management purposes

    --sysonly
    	Collect only system-related information w/o attempting to gather MariaDB, MaxScale, or Columnstore information.

    --maxonly
        Collect information only for MaxScale and then exit, without attempting to gather MariaDB server information.

    --colonly
        Collect basic information only for ColumnStore and then exit, without attempting to gather MariaDB or MaxScale server information.

    --help
        Display this text and exit.

EXAMPLES
    Minimum Required: running the script with a case number:
    ./mdb-support.sh --caseno 314159

    Running the script with custom MariaDB user credentials on an alternate port:
    ./mdb-support.sh --caseno 314159 --mdbu dba --mdbp s3cret --mdbP 63306

    Running the script for MaxScale only:
    ./mdb-support.sh --caseno 314159 --maxonly

NOTES
    Ensure that you have the necessary permissions to run the script on the MariaDB server.
    It is recommended to execute the script during a peak load time to gather the most relevant data.
    Avoid using password options in environments where command history is stored or monitored.

COPYRIGHT
    Copyright (c) 2024 MariaDB plc. All rights reserved, proprietary and confidential.
    Unauthorized modification, copying or distribution is prohibited.
    MariaDB product terms at https://mariadb.com/product-terms-condition/ apply.
    This script is for the use by MariaDB and MariaDB subscription customers only.
    If you are not authorized to use this script, please delete this script from all devices under your control.
    Support at https://support.mariadb.com
    Contact person: Juan Vera Huneeus
EOF
}

parse_args() {
	[ $# -eq 1 ]  && [ "$1" != '--help' ]  && {
		echo $1 | grep -q '='
		[ $? -eq 0 ] && caseno=$(echo $1 | cut -d '=' -f 2) || caseno=$1
	} || {
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					helpText
					exit 1
					;;
				--caseno)
					if [[ "$2" == *=* ]]; then
						caseno="${2#*=}"
					else
						caseno="$2"
						shift
					fi
					;;
				--dir)
					if [[ "$2" == *=* ]]; then
						outDir="${2#*=}"
					else
						outDir="$2"
						shift
					fi
					;;
				--logdays)
					if [[ "$2" == *=* ]]; then
						logDays="${2#*=}"
					else
						logDays="$2"
						shift
					fi
					;;
				--mdbu)
					if [[ "$2" == *=* ]]; then
						mdbu="${2#*=}"
					else
						mdbu="$2"
						shift
					fi
					;;
				--mdbp)
					if [[ "$2" == *=* ]]; then
						mdbp="${2#*=}"
					else
						mdbp="$2"
						shift
					fi
					;;
				--mdbP)
					if [[ "$2" == *=* ]]; then
						mdbP="${2#*=}"
					else
						mdbP="$2"
						shift
					fi
					;;
				--socket)
					if [[ "$2" == *=* ]]; then
						mxsu="${2#*=}"
					else
						mxsu="$2"
						shift
					fi
					;;
				--ssl|--skip-ssl)
					eval ${1:2}=1
					;;
				--ssl-ca)
					if [[ "$2" == *=* ]]; then
						mxsu="${2#*=}"
					else
						mxsu="$2"
						shift
					fi
					;;
				--ssl-capath)
					if [[ "$2" == *=* ]]; then
						mxsu="${2#*=}"
					else
						mxsu="$2"
						shift
					fi
					;;
				--ssl-cert)
					if [[ "$2" == *=* ]]; then
						mxsu="${2#*=}"
					else
						mxsu="$2"
						shift
					fi
					;;
				--ssl-cipher)
					if [[ "$2" == *=* ]]; then
						mxsu="${2#*=}"
					else
						mxsu="$2"
						shift
					fi
					;;
				 --ssl-key)
					if [[ "$2" == *=* ]]; then
						mxsu="${2#*=}"
					else
						mxsu="$2"
						shift
					fi
					;;
				--mxsu)
					if [[ "$2" == *=* ]]; then
						mxsu="${2#*=}"
					else
						mxsu="$2"
						shift
					fi
					;;
				--mxsp)
					if [[ "$2" == *=* ]]; then
						mxsp="${2#*=}"
					else
						mxsp="$2"
						shift
					fi
					;;
				--mxsP)
					if [[ "$2" == *=* ]]; then
						mxsP="${2#*=}"
					else
						mxsP="$2"
						shift
					fi
					;;
				--tls-key)
					if [[ "$2" == *=* ]]; then
						tlskey="${2#*=}"
					else
						tlskey="$2"
						shift
					fi
					;;
				--tls-passphrase)
					if [[ "$2" == *=* ]]; then
						tlspassphrase="${2#*=}"
					else
						tlspassphrase="$2"
						shift
					fi
					;;
				--tls-cert)
					if [[ "$2" == *=* ]]; then
						tlscert="${2#*=}"
					else
						tlscert="$2"
						shift
					fi
					;;
				--tls-ca-cert)
					if [[ "$2" == *=* ]]; then
						tlscacert="${2#*=}"
					else
						tlscacert="$2"
						shift
					fi
					;;
				--ssl|--skip-ssl|--secure|--instanceonly|--sysonly|--maxonly|--colonly|--debug)
					eval ${1:2}=1
					;;
				*=*)
					# Handle --key=value format
					key=${1%%=*}
					value=${1#*=}
					case "$key" in
						--caseno) caseno="$value" ;;
						--dir) outDir="$value" ;;
						--logdays) logDays="$value" ;;
						--mdbP) mdbP="$value" ;;
						--mdbu) mdbu="$value" ;;
						--mdbp) mdbp="$value" ;;
						--socket) socket="$value" ;;
						--ssl) ssl=1 ;;
						--skip-ssl) skipssl=1 ;;
						--ssl-ca) sslca="$value" ;;
						--ssl-capath) sslcapath="$value" ;;
						--ssl-cert) sslcert="$value" ;;
						--ssl-cipher) sslcipher="$value" ;;
						--ssl-key) sslkey="$value" ;;
						--mxsu) mxsu="$value" ;;
						--mxsp) mxsp="$value" ;;
						--mxsP) mxsP="$value" ;;
						--secure) secure=1 ;;
						--tls-key) tlskey="$value" ;;
						--tls-passphrase) tlspassphrase="$value" ;;
						--tls-cert) tlscert="$value" ;;
						--tls-ca-cert) tlscacert="$value" ;;
						--instanceonly) instanceonly=1 ;;
						--sysonly) sysonly=1 ;;
						--maxonly) maxonly=1 ;;
						--colonly) colonly=1 ;;
						--debug) debug=1 ;;
						*) 
							usage 
							;;
					esac
					;;
				*)
					usage
					;;
			esac
			shift
		done
	}
    [ -z "$mdbu" ] && mdbu=$(whoami)
    [ -z "$mdbP" ] && mdbP=3306
	[ -z "$mxsu" ] && mxsu="admin"
	[ -z "$mxsp" ] && mxsp="mariadb"
	[ -z "$mxsP" ] && mxsP=8989
	
	[ -d $outDir ] || {
        echo >&2
        echo "Error: --dir $outDir is not accessible." >&2
        echo >&2
        usage
	}

	echo $logDays | grep -Eq "^[0-9]*$"  
	[ $? -eq 0 ] || {
        echo >&2
        echo "Error: --logdays must be a natural number." >&2
        echo >&2
        usage
	}

    [ -z "$caseno" ] && {
        echo >&2
        echo "Error: Missing required parameter --caseno <MariaDB Case Number>." >&2
        echo >&2
        usage
    }
    echo "$caseno" | grep -Eq "^[0-9]{6,7}$" || {
        echo >&2
        echo "Error: --caseno (MariaDB Case Number) must be a 6 or 7 digit ticket #." >&2
        echo >&2
        usage
    }
    
}

# 
open_outfile() {
	outHeader="${outDir}/mdbs-$caseno-$(hostname)-$(date +%Y%m%d)"
	outFile="${outHeader}-sysinfo.out"
	# Kludge for asset inventory
	[ $instanceonly -eq 0 ] && {
		touch $outFile
		[ $? -ne 0 ] && echo "$HOSTNAME $0 $LINENO $(date) Error: $outFile is not writeable." >&2 && exit 1
		echo>$outFile
		date>>$outFile
		echo "$0 $ver">>$outFile
		echo>>$outFile
	}
}

# Check the status of a service using systemctl
check_systemctl_status() {
    service_name=$1
    systemctl status $service_name >/dev/null 2>&1
    return $?
}

# Check the status of a service using service command
check_service_status() {
    service_name=$1
    service $service_name status >/dev/null 2>&1
    return $?
}

# Check if either mariadb, mysqld, or mysql service is installed
check_service_presence() {
    check_systemctl_status mariadb
    testSRV=$?

    if [ $testSRV -ne 0 ]; then
        check_systemctl_status mysqld
        testSRV=$?
    fi

    if [ $testSRV -ne 0 ]; then
        check_service_status mysql
        testSRV=$?
    fi

    case $testSRV in
    0)
        hasSRV=1
        isRunning=1
        ;;
    3)
        hasSRV=1
        isRunning=0
        ;;
    *)
        hasSRV=0
        isRunning=0
        ;;
    esac
}

get_available_services() {
#echo "*** get_available_services() $LINENO"
	# If MariaDB client is installed, define executable and functions
	hasCLI=0
	cliExec="$(which mariadb 2>/dev/null)"
	if [ $? -ne 0 ]
	then
		cliExec="$(which mysql 2>/dev/null)"
		if [ $? -ne 0 ]
		then
			cliExec="$(find / -name mariadb -type f --executable 2>/dev/null)"
			if [ $? -ne 0 ]
			then
				cliExec="$(find / -name mysql -type f --executable 2>/dev/null)"
				[ $? -eq 0 ] && hasCLI=1
			else
				hasCLI=1
			fi
		else
			hasCLI=1
		fi
	else
		hasCLI=1
	fi

	# Check if either mariadb, mysqld, or mysql service is installed
	check_systemctl_status mariadb
	testSRV=$?
	
	if [ $testSRV -ne 0 ]; then
		check_systemctl_status mysqld
		testSRV=$?
	fi
	
	if [ $testSRV -ne 0 ]; then
		check_service_status mysql
		testSRV=$?
	fi
	
	case $testSRV in
	0)
		hasSRV=1
		isRunning=1
		;;
	3)
		hasSRV=1
		isRunning=0
		;;
	*)
		hasSRV=0
		isRunning=0
		;;
	esac
#echo "get_available_services() $LINENO hasCLI=$hasCLI, cliExec=$cliExec, testSRV=$testSRV, hasSRV=$hasSRV, isRunning=$isRunning"
}

# Is MariaDB accessible
is_mdb_accessible() {
#echo "is_mdb_accessible()  $LINENO hasCLI=$hasCLI, hasSRV=$hasSRV, cliExec=$cliExec"
    [ $hasCLI -eq 1 ] && {

        check_service_presence

        if [ $hasSRV -eq 0 ]; then
            hasAccess=0
        else
            hasAccess=1
#echo "is_mdb_accessible() $LINENO hasAccess=$hasAccess, mdbu='$mdbu', mdbp='$mdbp', before select NULL"
            haTest=$(xq "select null;" 2>/dev/null)
            haErr=$?
            hasAccess=0
#echo "is_mdb_accessible() $LINENO hasAccess=$hasAccess, mdbu='$mdbu', mdbp='$mdbp', haTest='$haTest', haErr='$haErr' after select NULL"
            
            if [ $haErr -ne 0 ] || [ "$haTest" != "NULL" ]; then
                $cliExec -u $mdbu $([ $mdbP -ne 3306 ] && echo "--port=$mdbP") -e "select null;" 2>&1 | grep -Eq "Access.*denied.*using.*password\:.*NO"
                [ $? -eq 0 ] && [ -z "$mdbp" ] && {
                	read -sp "Please enter a password for MariaDB user $mdbu : " -t $tPasswordR mdbp
                	echo
                }
                $cliExec -u $mdbu `[ -n "$mdbp" ] && echo ' -p$mdbp '` $([ $mdbP -ne 3306 ] && echo "--port=$mdbP") -e "select null;" 2>&1 | grep -Eq "Access.*denied.*using.*password\:.*NO"
                [ $? -eq 0 ] && { 
                    echo -n "$0 unable to query local MariaDB server with user $mdbu" | tee -a $outFile >&2
                    [ -z "$mdbp" ] && echo -n ' using entered password' | tee -a $outFile >&2
                    echo -ne ".\n"  | tee -a $outFile >&2
                } || {
                    hasAccess=1
                }
            else
                [ "$haTest" == "NULL" ] && hasAccess=1
            fi
        fi
    }
}

# Global variable query
# Returns the full list of global variables, or if a parameter is passed, returns the value for the variable matching the passed string. Partial matches not allowed 
gv() {
    [ -z "$1" ] && {
        $mdbd --help --verbose 2>/dev/null | grep ^[a-z] | grep -Ev "^and\ |^mariadbd" | tr -s '\t' ' '
    } || {
    	gvTarget="$(echo $1 | tr  '-' '_')"
    	$mdbd --help --verbose 2>/dev/null | grep ^[a-z] | grep -Ev "^and\ |^mariadbd" | tr -s '\t' ' ' | tr  '-' '_' | grep "^$gvTarget\ " | cut -d ' ' -f 2-
    }
}

# MariaDB CLI
xq() {

    local labels=$2
    local query=$(echo "$1" | sed 's/"/\\"/g')

    if [ $isRunning -eq 1 ] && [ $hasCLI -eq 1 ] && [ $hasAccess -eq 1 ]; then

		local args=()
		[ -n "$socket" ] && args+=( --socket "$socket" )
		[ -n "$ssl" ] && args+=( --ssl "$ssl" )
		[ -n "$skipssl" ] && args+=( --skip-ssl "$skipssl" )
		[ -n "$sslca" ] && args+=( --ssl-ca "$sslca" )
		[ -n "$sslcapath" ] && args+=( --ssl-capath "$sslcapath" )
		[ -n "$sslcert" ] && args+=( --ssl-cert "$sslcert" )
		[ -n "$sslcipher" ] && args+=( --ssl-cipher "$sslcipher" )
		[ -n "$sslkey" ] && args+=( --ssl-key "$sslkey" )
		args+=( -AB )
		[ -z "$labels" ] && args+=( -N )
		args+=( -u "$mdbu" )
		[ -n "$mdbp" ] && args+=( --password="$mdbp" )
		[ -n "$mdbP" ] && [ $mdbP -ne "3306" ] && args+=( --port "$mdbP" )
		args+=( -e "$query")
        
        local tmplog=$(mktemp /tmp/xq.XXXXXX)
         timeout $tErr $cliExec "${args[@]}" 2>$tmplog
		local retval=$?
		[ $retval -ne 0 ] && echo "$0 $cliExec error: $(cat $tmplog)">&2
		rm "$tmplog" 2>/dev/null
		return $retval
    else
        return 1
    fi
}

xql() {
    xq "$1" 1
    return $?
}

# MaxScale CLI
mxctl() {
   local args=()

    args+=( -u "$mxsu" -p "$mxsp" -h 127.0.0.1:$mxsP)

    [ -n "$secure" ] && args+=( --secure )
    [ -n "$tlskey" ] && args+=( --tls-key "$tlskey" )
    [ -n "$tlspassphrase" ] && args+=( --tls-passphrase "$tlspassphrase" )
    [ -n "$tlscert" ] && args+=( --tls-cert "$tlscert" )
    [ -n "$tlscacert" ] && args+=( --tls-ca-cert "$tlscacert" )

    args+=( "$@" )
    local tmplog=$(mktemp "/tmp/mdb.XXXXXX")
    timeout $tErr maxctrl "${args[@]}" 2>$tmplog
    local retval=$?
    [ $retval -ne 0 ] && echo "$0 maxctrl error: $(cat $tmplog)">&2
    rm $tmplog 2>/dev/null
    return $retval
}

get_identifiers() {

	#Determine distro flavor
	[ -e /etc/redhat-release ] && redhat=1 || redhat=0
	lsb_release -a 2>/dev/null >/dev/null
	[ $? -eq 0 ] && debian=1 || debian=0

	#ID host/user
	echo "host IP: $(hostname -I)" 2>/dev/null >>$outFile
	[ $? -ne 0 ] && echo "host IP: $(ip addr show | grep 'inet ' | awk '{print $2}' | grep -v "^127")" 2>/dev/null >>$outFile
	echo "mac: `cat /sys/class/net/*/address | grep -v "^00:00:00:00" | tr -s '\n' ' '` " >>$outFile
	[ $? -ne 0 ]  && echo "host IP: `ifconfig | grep -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"`" 2>/dev/null >>$outFile
	[ $redhat -eq 1 ] && cat /etc/redhat-release  >>$outFile
	[ $debian -eq 1 ] && lsb_release -a 2>/dev/null | grep Description | cut -d ':' -f 2- | tr -s ' ' | cut -c 2- >>$outFile
	mysql --version 2>/dev/null >>$outFile
	mysqld --version 2>/dev/null >>$outFile
	mariadbd --version 2>/dev/null >>$outFile
	mariadb-backup --version 2>/dev/null
	[ $? -ne 0 ] && mariabackup --version 2>/dev/null >>$outFile
	xtrabackup --version 2>/dev/null >>$outFile
	maxscale --version 2>/dev/null >>$outFile
	echo "user: $(whoami)" 2>/dev/null >>$outFile
	echo >>$outFile
}

get_iostat() {

	# Kludge for asset inventory
	[ $instanceonly -eq 1 ] && return

	# start this now so that customer is not waiting on iostat at the end
	iostatexe="$(which iostat 2>/dev/null)"
	if [ $? -eq 0 ]
	then
		iostatfile="${outHeader}-iostat.out"
		echo>$iostatfile
		$iostatexe -x -c -d -t 1  $(( $tStatusI + 15 )) | grep -E "^10|^avg|^Device|^$|\s[1-9]" >>$iostatfile &
	fi

}

ram_calc() {

	# RAM Calc
	[ $isRunning -eq 1 ] && [ $hasCLI -eq 1 ] && [ $hasAccess -eq 1 ] && {

		echo >>$outFile

		varnames=("aria_pagecache_buffer_size" "innodb_buffer_pool_size" "innodb_log_buffer_size" "key_buffer_size" "query_cache_size" "max_connections" "binlog_cache_size" "join_buffer_size" "read_buffer_size" "read_rnd_buffer_size" "sort_buffer_size" "thread_stack" "tmp_table_size" "slave_parallel_max_queued" "slave_parallel_threads")

		i=0
		varvals=()

		while [ $i -lt ${#varnames[@]} ]
		do
			query="show global variables like '${varnames[$i]}';"
			val=$(xq "$query" | tr -s '\t' ' ' | cut -d ' ' -f 2)
#echo "'${varnames[$i]}' '$val' '$query' '$(xq $query)'"
			[ -z $val ] && val=0
			varvals+=($val)
			let i++
		done
		
		#trc total ram configured
		trc=$(( ${varvals[0]} + ${varvals[1]} + ${varvals[2]} + ${varvals[3]} + ${varvals[4]} + ( ${varvals[5]} * ( ${varvals[6]} + ${varvals[7]} + ${varvals[8]} + ${varvals[9]} + ${varvals[10]} + ${varvals[11]} + ${varvals[12]}  ) ) + ( ${varvals[13]} * ${varvals[14]} ) ))

		#tra total ram available
		tra=$(( $(cat /proc/meminfo | grep MemTotal | tr -s '\t' ' ' | cut -d ' ' -f 2) * 1024 ))

		[ $trc -le $tra ] && echo "Total RAM required for configuration = $trc or $(( $trc / 1024 **2 ))M" >>$outFile || echo "CAUTION: Memory Appears Overallocated. As configured MariaDB can require up to $trc bytes RAM, but `hostname` only has $tra total bytes of RAM" >>$outFile
		echo >>$outFile
	}
}
# Done gathering information. Pacakge and finish
finished() {

	# Kludge for asset inventory
	[ $instanceonly -eq 0 ] && {
		#package files
		du -csh ${outHeader}* >> $outFile
		printf '%x' $(( $( du -csb $0 | grep total | tr -s '\t' ' ' | cut -d ' ' -f 1 ) % 16385 )) >> $outFile
		printf '%x\n' $(( $( du -csb ${outHeader}* | grep total | tr -s '\t' ' ' | cut -d ' ' -f 1 ) % 16385 )) >> $outFile
		tarfile="${outHeader}-support.tgz"
		[ -e $tarfile ] && rm -f $tarfile

		tar -zcf $tarfile ${outHeader}* 2>/dev/null
		# test for error log and message if missing
		errlogsize="$(tar -ztvf $tarfile 2>&1 | grep err | head -n 1 | tr -s '\t' ' ' | cut -d ' ' -f 3)"
		[ -z "$errlogsize" ] && [ $instanceonly -eq 0 ] && echo "Error logs not found. Please gzip and attach error logs manually if possible." >&2 || echo "#errlogsize $errlogsize ">>$outFile
		for i in $(ls -1 ${outHeader}* | grep -v "$tarfile")
		do
			rm -f $i
		done
	}
	
	#display list fo files collected
	echo
	echo "Files collected:"
	[ -f $tarfile ] && tar -ztvf $tarfile 2>/dev/null || ls -lh $outHeader*

	#announce completion
	echo
	echo "$(date) $0 finished in $(( $(date +%s) - $start )) sec."
	echo
	echo "Please attach `( [ -n "$tarfile" ] && [ -f $tarfile ] && echo $tarfile ) || ls -1 ${outHeader}* | tr -s '\n' ' '` to MariaDB Support Case Number $caseno"

	echo
	exit 0
}

# Get IOPS roughly corresponding to MariaDB IO capacity variable units of 16k pages per second
get_iops() {

	# Kludge for asset inventory
	[ $instanceonly -eq 1 ] && return
	
	#Get IOPS as InnoDB uses them.
	local iopsBlock=$(gv "innodb_page_size")
	[ -z "$iopsBlock" ] && iopsBlock=16384

	local iopsCount=$(( 33554432 / $iopsBlock ))
	flushMethod=$(gv "innodb_flush_method")
	[ -z "$flushMethod" ] && flushMethod='fsync'
	
	[ $flushMethod == "fsync" ] && local iopsFlush='fsync' || local iopsFlush='O_DIRECT'

	local dataDir=$(gv "datadir")
	[ -z "$dataDir" ] && dataDir="./"

	local rndString=$(head -c $iopsBlock /dev/urandom 2>/dev/null  | tr -d '\0')

	# Only run the test if the datadir was identified and is reachable
	if [ -d $dataDir ]
	then
		SECONDS=0
		#bioste=basic IO speed test error
		bioste=0
		#output file
		of=$(mktemp "${dataDir:-$HOME}/.fXXXXXX")
		[ $? -ne 0 ] && {
			echo "IOPS: N/A"  >>$outFile
			return 1
		}
		
		startTime=$(date +%s%N)
		
		n=0
		while [ $n -lt $iopsCount ]
		do
			#random number of 16k blocks at a time to simulate database writes
			i=$(( $RANDOM % 64 + 1 ))
			(( n += i )) 
			[ $n -gt $iopsCount ] && {
				local nDiff=$(( $n - $iopsCount ))
				n=$(( $n - $nDiff ))
			}
			
			aBlock=()
			for ((j=0; j<$i; j++))
			do
				aBlock+=($rndString)
			done
			[ $iopsFlush == 'fsync' ] && {
				echo -n "${aBlock[*]}" >> $of
				sync
			} || {
				dd if=<(echo -n "${aBlock[*]}") of=$of oflag=direct bs=$iopsBlock count=1 > /dev/null 2>&1
			}
		done
		
		# Measure the end time
		endTime=$(date +%s%N)
		
		# Remove test file
		rm -f $of
		
		# Calculate the duration in seconds
		duration_ns=$(( endTime - startTime ))
		
		# Calculate the IOPS
		iops=$(( iopsCount * 10**9 / duration_ns ))
		
		# Output
		echo >>$outFile
		echo "IOPS: $iops, $(( $iops * 64 )) fio equivalent, flush=$iopsFlush"  >>$outFile
	fi	

}

salad() {
	echo "$1" | tr 'A-Z0-4\_a-z\n5-9\ \-:\.\(\)' 'D-Z\%\$A-Cd-za-c\#\^\&\*0-9\~\!'
	[ -z "$1" ] && return 1
}

tailLog() {
    # Retrieve $targetDays days of real logs
    local sourceFile="$1"
    local targetFile="$2"
    local targetDays="$3"

    # Validate that targetDays is a positive integer
    if ! [[ "$targetDays" =~ ^[0-9]+$ ]] || [ "$targetDays" -le 0 ]; then
        echo "targetDays must be a positive integer."
        return 1
    fi

    # Get the current date in YYYYMMDD format
    local currentDate=$(date +%Y%m%d)

    # Calculate start date (targetDays days ago)
    local startDate=$(date -d "$targetDays days ago" +%Y%m%d)

    # Validate source file
    if [ -z "$sourceFile" ] || [ ! -f "$sourceFile" ]; then
        echo "Source file does not exist or is not specified."
        return 1
    fi

    # Process log file with awk
    awk -v start="$startDate" -v end="$currentDate" '
    function convert_date(log_date) {
        # Convert YYMMDD to YYYYMMDD by prefixing "20"
        return "20" log_date
    }
    {
        if ($0 ~ /^# Time: /) {
            # Extract date from the third field (YYMMDD)
            log_date_yy = $3
            log_date_yyyy = convert_date(log_date_yy)
            include = (log_date_yyyy >= start && log_date_yyyy <= end)
        }
        # Print line if within date range
        if (include) print
    }' "$sourceFile" > "$targetFile"
}

get_instance_info() {
	# 	For Subscription Information:
	# 	First generate output filename, then get:
	#		ISO 8601 Date
	# 		Hostname
	# 		IP
	# 		MAC
	# 		RAM in bytes
	# 		O/S
	# 		O/S Version
	# 		CPU Count
	# 		Product Versions	
	# 		server_uid
	
	# First generate output filename, then get:
	infoFile="${outHeader}-instanceinfoc.out"
	touch $infoFile
	echo >$infoFile
	#
	#ISO 8601 Date
	salad "date:$(date +"%Y-%m-%dT%H:%M:%S%z")" >>$infoFile

	# Hostname
	salad "hostname:`hostname`" >>$infoFile

	# IP
	ipv4="$(hostname -I)" 2>/dev/null
	[ $? -ne 0 ] && ipv4="$(ip addr show | grep 'inet ' | awk '{print $2}' | egrep -v "^127|\/")" 2>/dev/null >>$infoFile
	salad "IP:$ipv4" 2>/dev/null >>$infoFile

	# RAM in bytes
	# Docker
	docker=0
	if [ -f /.dockerenv ]
	then
		docker=1
		dockmem="$(( $(cat /sys/fs/cgroup/memory/memory.limit_in_bytes) / 1024 ))"
		[ "${docmem:0,7}" == "9007199" ] && foundmem=$(free -k | grep -i mem | awk '{print $2}') || foundmem=$dockmem
		salad "ram:$(( $foudmem * 1024 ))" >$infoFile
	else
		salad "ram:$(( $(cat /proc/meminfo | grep MemTotal | tr -s '\t' ' ' | cut -d ' ' -f 2) * 1024 ))" >>$infoFile
	fi
	salad "docker:$docker"  >>$infoFile

	# 		O/S
	#Determine distro flavor
	cat /etc/os-release 2>/dev/null | grep ID | grep -Eq "rhel|centos|fedora|rocky|almalinux|\"ol\"|cloudlinux|clearos"
	[ $? -eq 0 ] && redhat=1 || redhat=0
	cat /etc/os-release 2>/dev/null | grep ID | grep -Eq "debian|ubuntu|linuxmint|elementary|kali|raspbian|devuan|\"mx\""
	[ $? -eq 0 ] && debian=1 || debian=0
	salad "redhat:$redhat"  >>$infoFile
	salad "debian:$debian"  >>$infoFile
	# 		O/S Version
	salad "OS:$(cat /etc/os-release 2>/dev/null | grep 'PRETTY_NAME' | cut -d '=' -f 2-)" >>$infoFile
	# 		CPU Count
	salad "cpus:$(nproc --all 2>/dev/null)" >>$infoFile
	# 		Product Versions
	salad "mariadbd:$($mdbd --version 2>/dev/null)" >>$infoFile
	
	# server_uid
	salad "UID:`$mdbd --help --verbose 2>/dev/null | grep 'server-uid' | tr -s '\t' ' ' | cut -d ' ' -f 2-`" >>$infoFile
	# server id
	salad "server_id:`$mdbd --help --verbose 2>/dev/null | grep '^server-id' | tr -s '\t' ' ' | cut -d ' ' -f 2-`" >>$infoFile
		# 	port
	salad "port:`$mdbd --help --verbose 2>/dev/null | grep '^port ' | tr -s '\t' ' ' | cut -d ' ' -f 2-`" >>$infoFile

}

get_system_info() {

	# Kludge for asset inventory
	[ $instanceonly -eq 0 ] && sioutfile="$outFile" || sioutfile="/dev/null"
	
	# O/S
	echo >>$sioutfile
	cat /etc/os-release | grep -E "^PRETTY|ID_LIKE" | cut -d '"' -f 2 >>$sioutfile
	uname -a >>$sioutfile
	uptime >>$sioutfile
	echo -n "ulimit -n:" >>$sioutfile
	ulimit -n >>$sioutfile
	env | grep -Ei "^path|maria" >>$sioutfile
	[ -e /etc/nsswitch.conf ] && echo "Hostname resolution order: $(cat /etc/nsswitch.conf | grep ^hosts | tr -s '\t' ' ' | cut -d ' ' -f 2-)" >>$sioutfile

	# Available RAM / CPU Cores
	# Basic IO Speed
	get_iops >>$sioutfile
	# swappiness (default 60 for Ubuntu, 30 for CentOS)
	echo "/proc/sys/vm/swappiness=$(cat /proc/sys/vm/swappiness)" >>$sioutfile

	# Docker
	if [ -f /.dockerenv ]
	then
		dockmem="$(( $(cat /sys/fs/cgroup/memory/memory.limit_in_bytes) / 1024 ))"
		echo "*** Docker ***" >>$sioutfile
		[ "${docmem:0,7}" == "9007199" ] && foundmem=$(free -k | grep -i mem | awk '{print $2}') || foundmem=$dockmem
		echo "MemTotal: $foudmem" >$sioutfile
	else
		cat /proc/meminfo | grep MemTotal >>$sioutfile
	fi

	# Virtualization
	[ -e /sys/fs/cgroup/cpuset/cpuset.cpus ] && echo "Virtualized CPUs found - physical cores reported could be shared or hyperthreaded." >>$sioutfile

	echo "CPU counts:"  >>$sioutfile
	echo "physical $(cat /proc/cpuinfo | grep -E "core id|physical id" | tr -d "\n" | sed s/physical/\\nphysical/g | grep -v "^$" | sort | uniq | wc -l)"  >>$sioutfile
	echo "vcpu $(nproc --all)"  >>$sioutfile #nproc is part of coreutils

	# Top
	echo  >>$sioutfile
	echo "Top 5 by CPU then Memory" >>$sioutfile
	top -b -n 1  -o +%CPU | head -n 12 >>$sioutfile
	echo  >>$sioutfile
	top -b -n 1  -o +%MEM | head -n 12 | tail -n 6 >>$sioutfile

	# Disk space
	echo  >>$sioutfile
	echo "Disk space" >>$sioutfile
	df -h >>$sioutfile

	# Disk mounts
	echo  >>$sioutfile
	echo "Mounts" >>$sioutfile
	mount >>$sioutfile

	# Kludge for asset inventory
	[ $instanceonly -eq 0 ] && {
	
		# Installed packages
		echo  >>$sioutfile
		echo "Installed packages" >>$sioutfile
		if [ $redhat -eq 1 ]
		then
			yum list installed 2>/dev/null | grep -Ei "mariadb|mysql|galera|percona" >>$sioutfile
		else
			apt list --installed 2>/dev/null | grep -Ei "mariadb|mysql|galera|percona" >>$sioutfile
		fi
	
		# Available packages
		echo  >>$sioutfile
		echo "Available packages" >>$sioutfile
		if [ $redhat -eq 1 ]
		then
			yum list available 2>/dev/null | grep -Ei "mariadb|percona" >>$sioutfile
		else
			apt list 2>/dev/null | grep -v installed | grep -Ei "mariadb|percona" >>$sioutfile
		fi
	}
	
	# libraries
	echo  >>$sioutfile
	echo "Shared Library Dependencies (ldd):" >>$sioutfile
	ldd $(which mysqld 2>/dev/null) 2>/dev/null >>$sioutfile
	
	# service copnfiguration
	echo >>$sioutfile
	echo "MariaDB Service Configuration:" >>$sioutfile
	echo >>$sioutfile
	systemctl show mariadb | sort >>$sioutfile
	echo >>$sioutfile

}

get_maxscale_info() {
	# MaxScale
	which maxctrl >/dev/null 2>&1
	testmaxctrl=$?
	systemctl status maxscale >/dev/null 2>&1
	testmaxsvc=$?
	if [ $(( $testmaxctrl + $testmaxsvc )) -eq 0 ]
	then
		moutfile="${outHeader}-mxs-info.out"
		echo>$moutfile
		echo "$0 v $ver">>$moutfile
		echo>>$moutfile
		echo "MaxScale config:" >>$moutfile
		cat /etc/maxscale.cnf | sed -e 's/password.*/password=XXXX/' >>$moutfile
		for i in $(ls -1 /var/lib/maxscale/maxscale.cnf.d/)
		do
			echo >>$moutfile
			echo "/var/lib/maxscale/maxscale.cnf.d/$i" >>$moutfile
			cat /var/lib/maxscale/maxscale.cnf.d/$i | sed -e 's/password.*/password=XXXX/' >>$moutfile
		done

		#test for access & prompt for credentials on failure
		mfla=1	# MaxScale failed login attempts
		mxctl -q list servers 2>/dev/null
		while [ $? -ne 0 ] && [ $mfla -le $mlla ]
		do
			echo "$(date) $0 unable to log on to maxscale"
			mxup=""
			read -p "Please enter the username and password for the MaxScale administrative user separated by a space: " mxup
			echo
			mxu="$(echo $mxup | tr -s ',' ' ' | cut -d ' ' -f 1)"
			mxp="$(echo $mxup | tr -s ',' ' ' | cut -d ' ' -f 2)"
			let mfla++
			mxctl -q list servers 2>/dev/null
		done

		if [ $mfla -lt $mlla ]
		then
			echo "$(date) $0 starting MaxScale configuration collection"

			echo >>$moutfile
			echo "MaxScale running parameters">>$moutfile
			echo >>$moutfile
			for h in list show
			do
				for i in maxscale monitors servers services listeners filters
				do
					[ $h == "list" ] && [ $i == "maxscale" ] || {
						echo >>$moutfile
						echo "MaxScale $h $i" >>$moutfile
						mxctl $h $i >>$moutfile
					}
				done
				echo "#done" >>$moutfile
			done

			# MaxScale Error log
			mxLogDir=$(mxctl show maxscale | grep logdir | cut -d '"' -f 4)
			mxLogFile=$(ls -1rt $mxLogDir/ | tail -n 1)
			mxLogTmp="${outHeader}-mxs-error.log"
			tailLog "$mxLogDir/$mxLogFile" "$mxLogTmp" $logDays
			[ -s $mxLogTmp ] && gzip -qf $mxLogTmp || rm -f $errLogTmp 2>/dev/null

			#Collect syslogs regardless.
			journalctl -u maxscale --since "$logDays days ago" 2>/dev/null | gzip > ${outHeader}-mxs-system.log.gz

			hasmaxscale=1
		else
			echo "$0 $(date) Unable to log on to maxctrl w. supplied credentials." | tee -a $moutfile
			hasmaxscale=0
		fi
		
		#Maxscale service configuration
		echo >>$moutfile
		echo "MaxScale Service configuration:" >>$moutfile
		systemctl show masxscale 2>/dev/null | sort >>$moutfile

	else
		hasmaxscale=0
	fi
}

get_columnstore_info() {
	which mcsGetConfig >/dev/null 2>&1
	if [ $? -eq 0 ]
	then
		echo  >>$outFile 2>/dev/null
		echo "Columnstore" >>$outFile  2>/dev/null
		mcsGetConfig -a 2>/dev/null >>$outFile
		echo >>$outFile
		echo "Plugin Version: `xq "SELECT PLUGIN_AUTH_VERSION FROM information_schema.PLUGINS WHERE PLUGIN_NAME = 'Columnstore';"`">>$outFile  2>/dev/null
		echo >>$outFile

		# Columnstore logs (usually)
		tar -czhf ${outHeader}-columnstore-logs.tgz /var/log/mariadb >>/dev/null 2>&1

		hasColumnstore=1
	else
		hasColumnstore=0
	fi
}

get_mdb_config_files() {
	cnfoutfile="${outHeader}-cnf"
	[ -f /etc/my.cnf ] && {
		tar -chf $cnfoutfile /etc/my.cnf >>/dev/null 2>&1
		for i in $(grep -EiR "\!includedir" /etc/my* 2>/dev/null| tr -s '\t' ' ' | cut -d ' ' -f 2)
		do
			[ -d $i ] && tar -rhf $cnfoutfile $i >>/dev/null 2>&1
		done
	}
	[ -f /etc/mysql/my.cnf ] && {
		tar -chf $cnfoutfile /etc/mysql >>/dev/null 2>&1
		for i in $(grep -EiR "\!includedir" /etc/mysql/* 2>/dev/null | tr -s '\t' ' ' | cut -d ' ' -f 2)
		do
			[ -d $i ] && tar -rhf $cnfoutfile $i  >>/dev/null 2>&1
		done
	}
	[ -f $cnfoutfile ] && {
		gzip -qf $cnfoutfile
		mv ${cnfoutfile}.gz ${cnfoutfile}.tgz
	}
}

get_error_logs() {

	errLogTmp="${outHeader}-mdb-err.log"
	sysLogTmp="${outHeader}-mdb-sys.log"
	[ $isRunning -eq 1 ] && errLog=$(xq "select @@log_error;")
	[ -z $errLog ] && errLog="$(gv 'log_error')"
	if [ -z "$errLog" ] #if there's no log in the running config
	then
		if [ $(ls -1 /var/log/ | grep -Ei "maria|mysql" | grep -Eiv "slow|gen" | wc -l ) -eq 1 ] && [ -f $(ls -1 /var/log/ | grep -Ei "maria|mysql" | grep -Eiv "slow|gen" ) ]
		then
			# If we find one maria error-log-looking file in /var/log/ that is not a slow or general log (hopefully)
			errLog=$(ls -1 /var/log/ | grep -Ei "maria|mysql" | grep -Eiv "slow|gen" | tail -n 1)
			tailLog "/var/log/$errLog" "$errLogTmp" $logDays
		elif [ $(ls -1 `xq "select @@datadir;"` | grep -i 'err' | grep -Eiv "slow|gen" | wc -l ) -eq 1 ]
		then
			# If we find one mysql error-log-looking file in the datadir that is not a slow or general log (hopefully)
			dataDir=`xq "select @@datadir;"`
			errLog=$(ls -1 $dataDir | grep -Ei "err|log$" | grep -Eiv "slow|gen|^ddl|^aria|^xtrabackup|^ib\_|gz$" | tail -n 1)
			tailLog "${dataDir}$errLog" "$errLogTmp" $logDays
		fi
	else
		[ ${errLog:0:2} == './' ] && errLog="${errLog:2}"
		[ $(echo $errLog | grep -q '/'; echo $?) -eq 0 ] || {
			datadir="$(xq 'select @@datadir;')"
			[ -z $dataDir ] && dataDir="/var/lib/mysql/"
			errLog="$dataDir$errLog"
		}
		tailLog "$errLog" "$errLogTmp" $logDays
	fi

	[ -s $errLogTmp ] && gzip -qf $errLogTmp || rm -f $errLogTmp 2>/dev/null

	#Collect syslogs regardless.
	if [ $(journalctl -u mariadb --since "$logDays days ago" 2>/dev/null | grep -Ev "No entries|Logs begin|Unit not found" | wc -l) -gt 0 ]
	then
		# If we find lines in the mariadb syslog
		journalctl -u mariadb --since "$logDays days ago" 2>/dev/null >$sysLogTmp
	elif [ $(journalctl -u mysql --since "$logDays days ago" 2>/dev/null | grep -Ev "No entries|Logs begin|Unit not found" | wc -l) -gt 0 ]
	then
		# If we find lines in the mysql syslog
		journalctl -u mysql --since "$logDays days ago" 2>/dev/null >$sysLogTmp
	fi
	[ -s $sysLogTmp ] && gzip -qf $sysLogTmp || rm -f $sysLogTmp 2>/dev/null

	#Collect SST logs if available
	if [ $isRunning -eq 1 ]
	then
		dDir=$(xq "select @@datadir;")
	else
		dDir="$(grep -ER '^datadir' /etc/my* 2>/dev/null | tail -n 1 | cut -d '=' -f 2-)"
	fi
	sstLog=$(grep -ER "sst[-_]log[-_]archive[-_]dir" /etc/my* 2>/dev/null | cut -d '=' -f 2- | tail -n 1) 
	[ -z $sstLog ] && sstLog=$(echo "$dDir/.sst" | tr -s '/')
	[ -e $sstLog ] && tar -czhf "${outHeader}-mdb-sst.log.tgz" ${sstLog}* 2>/dev/null
}

get_slow_log() {
	if [ $isRunning -eq 1 ]
	then
		dDir=$(xq "select @@datadir;")
		sqLogFile=$(xq "select @@slow_query_log_file;")
	else
		dDir="$(gv 'datadir')"
		sqLogFile="$(gv 'slow_query_log_file')"
	fi
	[ -n "$sqLogFile" ] && {
		sqLogFileFull=$( [ ${sqLogFile:0:1} == '/' ] && echo "$sqLogFile" || echo "${dDir}$sqLogFile")
		slOutFile="${outHeader}-slow.log"
		if [ -e $sqLogFileFull ] && [ $(cat $sqLogFileFull | wc -l) -gt  2 ]
		then
		
			tailLog "$sqLogFileFull" "$slOutFile" $logDays
			
			gzip $slOutFile
		fi
	}
}

get_mdb_globals() {
	[ $isRunning -eq 1 ] && {
		#Global variables modified
		echo "$(date) $0 gathering global variable & status information. Please stand by..."
	
		echo >>$outFile
		echo "Global Variables Configured Values:">>$outFile
		echo >>$outFile
		n=$(xq "select variable_name, global_value, global_value_origin, global_value_path from information_schema.system_variables WHERE global_value_origin='CONFIG' order by variable_name;" | wc -l)
		[ $n -gt 0 ] && {
			xq "select variable_name, global_value, global_value_origin, global_value_path from information_schema.system_variables WHERE global_value_origin='CONFIG' order by variable_name;" | tr '[:upper:]' '[:lower:]' | sort >>$outFile
		} || {
			mysqld --print-defaults 2>/dev/null | sed 's/--/~/g' | tr -s '~' '\n' | sort >>$outFile
		}
	
		# Global Variables & Status x2 $tStatusI s apart
		echo >>$outFile
		gv1="/tmp/$RANDOM"
		xq "show global variables;" | sort | sed 's/; /;~\&/g' | tr -s '~' '\n' | tr -s '\&' '\t' >>$gv1
		gs1="/tmp/$RANDOM"
		xq "show global status;" | sort | tr -s '\t' ' '>>$gs1
		sleep $tStatusI
		gv2="/tmp/$RANDOM"
		xq "show global variables;" | sort | sed 's/; /;~\&/g' | tr -s '~' '\n' | tr -s '\&' '\t' >>$gv2
		gs2="/tmp/$RANDOM"
		xq "show global status;" | sort | tr -s '\t' ' '>>$gs2
	
		gvOut=""
		i=0
		while [ $i -lt $(cat $gv1 | wc -l) ]
		do
			let i++
			gvLine="$(cat $gv1 | head -n $i | tail -n 1)"
			gvv1="$(cat $gv1 | head -n $i | tail -n 1 | tr -s '\t' ' ' | cut -d ' ' -f 2)"
			gvv2="$(cat $gv2 | head -n $i | tail -n 1 | tr -s '\t' ' ' | cut -d ' ' -f 2)"
			if [ "$gvv1" == "$gvv2" ]
			then
				gvOut="$gvOut\n$gvLine"
			else
				echo $gvv2 | grep -Eq "^[0-9]*$"
				eg2=$?
				echo $gvv1 | grep -Eq "^[0-9]*$"
				eg1=$?
	
				if [ $eg2 -eq 0 ] && [ $eg1 -eq 0 ]
				then {
					gvOut="$gvOut\n$gvLine\t$gvv2\t$(( $gvv2 - $gvv1 ))"
				} else {
					gvOut="$gvOut\n$gvLine\t$gvv2"
				} fi
			fi
		done
		rm -f $gv1
		rm -f $gv2
		echo "Global Variables Running (w. ${tStatusI}s diff where appropriate):">>$outFile
		echo $gvOut | sed 's/\\n/~/g' | tr '~' '\n' | sed 's/\\t/~/g' | tr '~' '\t'>>$outFile
	
		gsOut=""
		i=0
		while [ $i -lt $(cat $gs1 | wc -l) ]
		do
			let i++
			gsLine="$(cat $gs1 | head -n $i | tail -n 1)"
			gsv1="$(cat $gs1 | head -n $i | tail -n 1 | tr -s '\t' ' ' | cut -d ' ' -f 2)"
			gsv2="$(cat $gs2 | head -n $i | tail -n 1 | tr -s '\t' ' ' | cut -d ' ' -f 2)"
			if [ "$gsv1" == "$gsv2" ]
			then
				gsOut="$gsOut\n$gsLine"
			else
				echo $gsv2 | grep -Eq "^[0-9]*$"
				eg2=$?
				echo $gsv1 | grep -Eq "^[0-9]*$"
				eg1=$?
	
				if [ $eg2 -eq 0 ] && [ $eg1 -eq 0 ]
				then
					gsOut="$gsOut\n$gsLine\t$gsv2\t$(( $gsv2 - $gsv1 ))"
				else
					gsOut="$gsOut\n$gsLine\t$gsv2"
				fi
			fi
		done
		rm -f $gs1
		rm -f $gs2
		echo >>$outFile
		echo >>$outFile
		echo "Global Status (w. ${tStatusI}s diff where appropriate):">>$outFile
		echo $gsOut | sed 's/\\n/~/g' | tr '~' '\n' | sed 's/\\t/~/g' | tr '~' '\t'>>$outFile
		echo >>$outFile
	} || {
		echo >>$outFile
		echo "Global Variables Configured Values (Server Not Running or Not Accessible):">>$outFile
		gv >>$outFile
		echo >>$outFile

	}
	echo "$(date) $0 continuing..."
}

get_grants() {
	#Get privileges for current user
	echo >>$outFile
	echo "Grants for relevant users:">>$outFile
	xq "show grants;" | grep -v 'PUBLIC' | sed -E "s/\*[A-Z0-9]{40,50}/XXXXXXXXXX/" >>$outFile
	echo >>$outFile

	#Get sst user if one exists
	sstu=`grep -R "wsrep[-_]sst[-_]auth" /etc/my* 2>/dev/null | grep -v Binary | tail -n 1 | cut -d ':' -f 2 | cut -d '=' -f 2`
	[ -n $sstu ] && {
		echo >>$outFile
		xq "show grants for '$sstu'@'localhost';" | sed -E "s/\*[A-Z0-9]{40,50}/XXXXXXXXXX/" >>$outFile
		echo >>$outFile
	}
	
	#Find any user with replication slave privilege and report them as well
	for i in $(xq "select concat( '''', user,'''@''', host, '''') from mysql.user where Repl_slave_priv='Y' and Select_priv='N';")
	do
		xq "show grants for $i;" | sed -E "s/\*[A-Z0-9]{40,50}/XXXXXXXXXX/" >>$outFile
		echo >>$outFile		
	done
	
}

get_galera() {
	# Galera inter-node ping times
	isgalera=$(xq "select @@wsrep_on;")

	if [ "$isgalera" == "1" ]
	then
		echo >>$outFile
		echo "Cluster RTT:">>$outFile
		addys=$( xql "show global status like 'wsrep_incoming_addresses';" | grep 'wsrep_incoming_addresses' | cut -c 26- )
		echo $addys | grep -iq 'AUTO'
		if [ $? -eq 0 ]
		then
			addys="$( xq 'show global variables like "wsrep_cluster_address";' | cut -d '/' -f 3-)"
		fi
		for i in $( echo $addys | tr -s ',' '\n' )
		do
			node="$(echo $i | cut -d ':' -f 1)"
			echo "$node $(ping -c $rttCount -t 2 $node 2>/dev/null| grep rtt)">>$outFile
		done
		echo>>$outFile
	
	fi

}

get_mdb_info() {

	if [ $hasCLI -eq 1 ]
	then

		get_error_logs

		get_slow_log

		if [ $isRunning -eq 1 ] && [ $hasAccess -eq 1 ]
		then

			get_mdb_globals

			echo "Binary Logs:">>$outFile
			mdbbinlog="$(xq 'select @@log_bin;')"
[ -z "$mdbbinlog" ] && mdbbinlog=0
			if [ $mdbbinlog -eq 0 ]
			then
				echo "disabled" >>$outFile
			else
				blcount=$(xq "show binary logs;" | wc -l)
				if [ $blcount -gt $inLineLimit ]
				then
					bloutfile="${outHeader}-binlog-list.out"
					echo "Binlog list too long; spooled out to $bloutfile" >>$outFile
				else
					bloutfile=$outFile
				fi
				[ "$bloutfile" == "$outFile" ] || echo "Binary Logs:">>$bloutfile
				xq "show binary logs;" >>$bloutfile
				echo >>$outFile
			fi

			# Engine InnoDB Status
			echo >>$outFile
			xq "show engine innodb status;"  | sed 's/\\n/\n/g' >>$outFile

			# Process List
			echo >>$outFile
			ploutfile=$outFile
			plout=$(xq "show full processlist;" | sed 's/\\n/\n\t/g')
			plc=$(echo "$plout" | wc -l)
			if [ $plc -gt $inLineLimit ]
			then
				ploutfile="${outHeader}-ps.out"
				echo "Process list $plc lines long; spooled out to $ploutfile" >>$outFile
			fi
			echo "Processlist:" >>$ploutfile
			echo "$plout" >>$ploutfile

			# Datadir file sizes
			echo >>$outFile
			echo "Datadir Filesizes (filtering out binlogs listed elsewhere):">>$outFile
			du -csh $(xq "select @@datadir;")* | grep -Ev "\.[0-9]{5,9}$" >>$outFile

			# Data size
			echo >>$outFile
			echo "Dataset Size:">>$outFile
			xq "select ifnull(B.engine,'Total') 'Storage Engine', concat(lpad(format( B.DSize/power(1024,pw),3),17,' '),' ',substr(' KMGTP',pw+1,1),'B') 'Data Size', concat(lpad(format(B.ISize/power(1024,pw),3),17,' '),' ', substr(' KMGTP',pw+1,1),'B') 'Index Size',concat(lpad(format(B.TSize/ power(1024,pw),3),17,' '),' ',substr(' KMGTP',pw+1,1),'B') 'Table Size' from (select engine,sum(data_length) DSize, sum(index_length) ISize,SUM(data_length+index_length) TSize from information_schema.tables where table_schema not in ('mysql','information_schema','performance_schema') AND engine is not null group by engine with rollup) B,(SELECT 2 pw) A order by TSize;" >>$outFile

			# Tables with no primary key, w. compression, or partitioned.
			echo >>$outFile
			xq "select 'Tables with Compression:', count(*) from information_schema.tables where lower(create_options) like '%essed%'; select 'Tables with No Primary Key:', count(*) from information_schema.tables as t left join information_schema.key_column_usage as c on ( t.table_name = c.table_name and c.constraint_schema = t.table_schema and lower(c.constraint_name) = 'primary' ) where t.table_schema not in ( 'information_schema', 'performance_schema', 'mysql' ) and lower(t.table_type) <> 'view' and c.constraint_name IS NULL order by t.table_schema, t.table_name; select 'Table Partition Count:', count(*) from information_schema.partitions where TABLE_SCHEMA not in ('performance_schema','sys','mysql','information_schema') and partition_ordinal_position is not null;" >>$outFile

			# Schema & table counts...
			echo >>$outFile
			xq "select 'Total Schema Count', count(distinct table_schema) from  information_schema.tables where table_schema not in ('mysql','performance_schema', 'information_schema', 'sys');" >>$outFile
			xq "select 'Total Table Count', count(1) from  information_schema.tables where table_schema not in ('mysql','performance_schema', 'information_schema', 'sys');" >>$outFile

			# Row formats
			echo >>$outFile
			xql "select table_type, engine, row_format, count(*) from information_schema.tables where table_schema not in ( 'mysql', 'information_schema', 'performance_schema', 'sys') group by table_type, engine, row_format;" >>$outFile

			# Replication Status
			echo >>$outFile
			echo "Replication Status:">>$outFile
			xql "show master status;" >>$outFile
			echo >>$outFile
			xql "show all slaves status\G" >>$outFile

			# Plugins
			echo >>$outFile
			echo "Plugins" >>$outFile
			echo >>$outFile
			xq "select PLUGIN_NAME, PLUGIN_VERSION from information_schema.PLUGINS where PLUGIN_STATUS='ACTIVE' order by PLUGIN_NAME;" | tr '[:upper:]' '[:lower:]' >>$outFile

			# Performance schema instruments
			psicount=$(xq "select count(*) from performance_schema.setup_consumers where enabled = 'YES';")
[ -z "$psicount" ] && psicount=0
			if [ $psicount -gt 0 ]
			then
				psiout="${outHeader}-perfschema.out"
				echo "$(hostname) $(date) Performance Schema" >>$psiout
				echo >>$psiout
				echo "Consumers" >>$psiout
				echo >>$psiout
				xq "select name from performance_schema.setup_consumers where enabled = 'YES';" >>$psiout
				echo "Instruments" >>$psiout
				echo >>$psiout
				xq "select name,timed from performance_schema.setup_instruments where enabled = 'YES';" >>$psiout
			fi

			get_galera
			
			get_grants

			# Replica ping times
			isreplica=$(xql "show slave status\G" | grep 'Master_Host' | wc -l)

			if [ "$isreplica" == "1" ]
			then
				echo >>$outFile
				echo "RTT to primary:">>$outFile
				for i in $(xql "show all slaves status\G" | grep 'Master_Host' | cut -d ':' -f 2-)
				do
					echo "$i $(ping -c $rttCount -t 2 $i | grep rtt)">>$outFile
				done
				echo>>$outFile
			fi

			echo "$(date) $0 almost there..."

			# Events & Schema count
			echo >>$outFile
			echo "Events" >>$outFile
			sc=0

			for i in `echo $xqsd | tr -s ' ' '\n' | grep -Ev "^information_schema$|^performance_schema$|^sys$|lost\+found$"`
			do
				let sc++
				scEv=`xq "show events from $i;"`
				[ $? -ne 0 ] && [ $debug -ne 0 ] && echo "$0 $LINENO error"
				if [ -n "$scEv" ]
				then
					echo >>$outFile
					echo "Events for $i;" >>$outFile
					echo "$scEv" >>$outFile
				fi
			done
		fi
	fi
}

main() {
    parse_args "$@"
    open_outfile

    [ $instanceonly -eq 0 ] && get_identifiers
    get_available_services
    get_system_info
    [ $instanceonly -eq 0 ] && get_mdb_config_files
    is_mdb_accessible
    
    get_instance_info
    [ $instanceonly -eq 1 ] && finished && exit 0

    [ $sysonly -eq 0 ] && {
    
        [ $colonly -eq 0  ] && get_maxscale_info
        [ $maxonly -ne 0  ] && finished && exit 0	#continue only if maxonly not set

        [ $maxonly -eq 0  ] && get_columnstore_info
        [ $colonly -ne 0  ] && finished && exit 0	#continue only if colonly not set

	    get_iostat
        get_mdb_info
        ram_calc

    }

    finished
}

main "$@"
