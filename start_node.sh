#!/bin/bash

mysql -e "START GROUP_REPLICATION;"
mysql -e "SELECT * FROM performance_schema.replication_group_members;"
echo Node Started
