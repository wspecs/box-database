#!/bin/bash

mysql -e "SET GLOBAL group_replication_bootstrap_group=ON;"
mysql -e "START GROUP_REPLICATION;"
mysql -e "SET GLOBAL group_replication_bootstrap_group=OFF;"
mysql -e "SELECT * FROM performance_schema.replication_group_members;"
echo Node Started
