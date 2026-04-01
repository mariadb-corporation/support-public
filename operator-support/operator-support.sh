#!/bin/bash
# operator-support.sh
# script by Edward Stoever for MariaDB support
# last modified April 1, 2026

URL="https://operator.mariadb.com/scripts/support.sh"

curl -o enterprise-operator-support.sh -sLO  ${URL}  || ERR=true

if [ $ERR ]; then
   echo "curl got an error!"; exit 1
else 

  if [ $(grep 404 enterprise-operator-support.sh |wc -l) != "0" ]; then 
    echo "Check the URL ${URL} to ensure the latest version can be downloaded. Try it in a browser!"; exit 1;
  fi  
fi

chmod 755 enterprise-operator-support.sh

cat <<EOF
Note: Always inspect bash scripts you download before running them.
In order to use it, you need to pass as argument:
Namespace where the MariaDB and other CRs are available
Namespace where the operator is running

This is the expected output:


./enterprise-operator-support.sh databases operator

Starting MariaDB Operator Data Collection...
Log files will be saved in: mariadb_support_2026-03-18_16-54-22
Target MariaDB Namespace: media
Target Operator Namespace: database
----------------------------------------------------------------------
[1/5] Collecting current namespace state (all resources)...
[2/5] Collecting logs from all pods and containers in 'databases'...
[3/5] Extracting Kubernetes events sorted by creation timestamp...
[4/5] Extracting Custom Resources...
[5/5] Extracting Operator logs from 'database'...
NAME                                  READY   UP-TO-DATE   AVAILABLE   AGE
mariadb-enterpriseoperator            1/1     1            1           234d
mariadb-enterprise-operator-webhook   1/1     1            1           234d
Please enter the Deployment name for the MariaDB Enterprise Operator from the list above [mariadb-enterprise-operator]: mariadb-enterprise-operator
----------------------------------------------------------------------
📋 Please provide the following environment details:
Kubernetes version: 1.35
Kubernetes distribution (Vanilla, OpenShift, EKS, GKE, AKS, etc.): OpenShift
MariaDB Operator version: 26.3.1
MariaDB Server version: 11.8.5
MariaDB topology (Replication, Galera, Standalone): Replication
MaxScale version: 25.10.1
Install method (Helm, OLM): OLM
Air-Gapped (Yes, No): Yes
(Optional) OpenShift version: 4.20
(Optional) OpenShift channel: stable
----------------------------------------------------------------------
📦 Creating archive: mariadb_support_2026-03-18_16-54-22.tar.gz...
🧹 Cleaning up temporary directory...
----------------------------------------------------------------------
✅ Data collection complete!
======================================================================
A tarball will be created with the debug information. 
EOF