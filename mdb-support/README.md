
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
        Specify the related support ticket number - 6 or 7 digits.
        
    --dir TARGET-DIRECTORY
        Specify the location where support output files will be stored. Defaults to current user home directory.

    --logdays LOG-DAYS
        Specify the number of days of logs to collect. Defaults to 60 days.

    --mdbu MDBUser
        Specify the MariaDB username if different from the current user "`whoami`".

    --mdbp MDBPassword
        Specify the MariaDB user's password. Use this option with caution as it exposes passwords
        in the shell's command history. In case the password has any special characters or spaces, 
        it can be quoted using single quotes like this: --mdbp 's#cr3t w0rd!'
        Quotes can be used interactively the same way.

    --mdbP MDBPort
    	Specify the configured listener port for MariaDB if different from the default 3306.

    --socket=path
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

    --ssl-key=name
           MariaDB Server connection X509 key in PEM format.

    --mxsu MXSUser
        Specify the MaxScale admin user name if different from the default "admin".

    --mxsp MXSPassword
        Specify the MaxScale admin user password if different from the default "mariadb".

    --mdbP MDBPort
    	Specify the configured listener port for MariaDB if different from the default 3306.

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
    List of supported operating systems at https://mariadb.com/engineering-policies/.

COPYRIGHT
    Copyright (c) 2024 MariaDB plc. All rights reserved, proprietary and confidential.
    Unauthorized modification, copying or distribution is prohibited.
    MariaDB product terms at https://mariadb.com/product-terms-condition/ apply.
    This script is for the use by MariaDB and MariaDB subscription customers only.
    If you are not authorized to use this script, please delete this script from all devices under your control.
    Support at https://support.mariadb.com
    Contact person: Juan Vera Huneeus