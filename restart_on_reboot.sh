#!/bin/bash

CONFIG_FILE=${CONFIG_FILE:-/etc/mysql/my.cnf}

sed -i "#start_on_boot = OFF#start_on_boot = ON#" $CONFIG_FILE
systemctl restart mysql
echo Installation completed

