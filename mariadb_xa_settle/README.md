# Mariadb XA Settle
Commit or rollback all unsettled XA transactions

To download the Mariadb XA Settle script direct to your linux server, you may use git or wget:
```
git clone https://github.com/mariadb-edwardstoever/mariadb_xa_settle.git
```
```
wget https://github.com/mariadb-edwardstoever/mariadb_xa_settle/archive/refs/heads/main.zip
```

### Overview
This script is to commit or rollback all pending XA transactions that are in a state of PREPARE. It is possible for an XA transaction to remain unsettled even after a restart of the database instance. It is possible for XA transactions to remain uncommitted, blocking other transactions for a long time.

### Use at your own risk
This script is provided to you entirely for use at your own risk. 

### Connecting from the database host
The most simple method for running Mariadb XA Settle is via unix_socket as root on the database host. If you want another user to connect to the database, add a user and password to the file `xa_settle.cnf`.

### Running a testing scenario
You can set up a schema with PREPARED XA TRANSACTIONS by running the script setup_test_xa_schema.sh:
```
./setup_test_xa_schema.sh
```
This will create a schema `test_xa` with a table `xa_table` then PREPARE five XA transactions without commiting them. Run the script multiple times if you want more uncommitted transactions.

### Settling uncommited XA transactions.

Use the script `mariadb_xa_settle.sh` to settle transactions.

### Examples of running the script on the command line
```
./mariadb_xa_settle.sh --help
./mariadb_xa_settle.sh --report
./mariadb_xa_settle.sh --commit_all
./mariadb_xa_settle.sh --rollback_all
./mariadb_xa_settle.sh --interactive --commit_all
./mariadb_xa_settle.sh --interactive --rollback_all
```

### Available Options
```
The following options are available.
   --interactive    # run as a human-interactive script.
   --report         # displays a report of prepared transactions not yet commit or rollback
   --commit_all     # commit all prepared XA transactions
   --rollback_all   # rollback all prepared XA transactions
   --help           # Display the help menu
```
The script can be called by another script like a command, or in human interactive mode with the flag `--interactive`

### cleanup after testing. 
Run the script `cleanup_test_xa_schema.sh` to drop the schema test_xa. Example:
```
./cleanup_test_xa_schema.sh
```
