#!/bin/bash

source /etc/wspecs/global.conf
source /etc/wspecs/functions.sh

function join() {
    # $1 is return variable name
    # $2 is sep
    # $3... are the elements to join
    local retname=$1 sep=$2 ret=$3
    shift 3 || shift $(($#))
    printf -v "$retname" "%s" "$ret${@/#/$sep}"
}

function setup_group_replication() {
    mysql -e "SET SQL_LOG_BIN=0;"
    mysql -e "CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY '${GROUP_PASSWORD}' REQUIRE SSL;"
    mysql -e "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';"
    mysql -e "FLUSH PRIVILEGES;"
    mysql -e "SET SQL_LOG_BIN=1;"
    mysql -e "CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='${GROUP_PASSWORD}' FOR CHANNEL 'group_replication_recovery';"
    mysql -e "SHOW PLUGINS;"
    if [[ $(mysql -e "SHOW PLUGINS;" | grep group_replication | head -c1 | wc -c) -eq 0 ]]; then 
      mysql -e "INSTALL PLUGIN group_replication SONAME 'group_replication.so';"
    fi
    mysql -e "SHOW PLUGINS;"
}

function start_first_node() {
  mysql -e "SET GLOBAL group_replication_bootstrap_group=ON;"
  mysql -e "START GROUP_REPLICATION;"
  mysql -e "SET GLOBAL group_replication_bootstrap_group=OFF;"
  mysql -e "SELECT * FROM performance_schema.replication_group_members;"
  echo Node Started
}

start_node() {
  mysql -e "RESET MASTER;"
  mysql -e "START GROUP_REPLICATION;"
  mysql -e "SELECT * FROM performance_schema.replication_group_members;"
  echo Node Started
}

CONFIG_FILE=${CONFIG_FILE:-/etc/mysql/my.cnf}
ALLOW_IP=${ALLOW_IP:-10.108.0.0/20}
UNIQUE_ID="${UNIQUE_ID:-$(uuidgen)}"
CURRENT_IP=$(curl 169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address && echo)
SERVER_ID=1

if [ ! -z "${SETUP_GROUP_REPLICATION+x}" ]; then
  setup_group_replication
  exit
fi

if [ ! -z "${START_FIRST_NODE+x}" ]; then
  start_first_node
  exit
fi

if [ ! -z "${START_NODE+x}" ]; then
  start_node
  exit
fi

if [ ! -z "${FINISH_INSTALLATION+x}" ]; then
  sed -i "#start_on_boot = OFF#start_on_boot = ON#" $CONFIG_FILE
  systemctl restart mysql
  echo Installation completed
  exit
fi

SERVERS=($DATABASE_SERVERS)
for i in "${!SERVERS[@]}"; do
  if [[ "${SERVERS[$i]}" = "${CURRENT_IP}" ]]; then
    SERVER_ID=$(echo ${i} + 1 | bc)
  fi
done
join IPS , ${DATABASE_SERVERS}
join SEED :33061, ${DATABASE_SERVERS}
SEEDS=${SEED}:33061


# Store unique config
add_config UNIQUE_ID=$UNIQUE_ID /etc/wspecs/global.conf

install_once mysql-server
sed "s#SERVER_ID#$SERVER_ID#" my.cnf > $CONFIG_FILE
sed -i "s#UNIQUE_ID#$UNIQUE_ID#" $CONFIG_FILE
sed -i "s#CURRENT_IP#$CURRENT_IP#" $CONFIG_FILE
sed -i "s#IPS#$IPS#" $CONFIG_FILE
sed -i "s#SEEDS#$SEEDS#" $CONFIG_FILE

systemctl restart mysql

# Start group replication installation
setup_group_replication

if [[ "${SERVER_ID}" = 1 ]]; then
  echo starting first node
  start_first_node
else
  while :  # Wait for first node to start first
  do
    if [[ $(mysql -e "SELECT * FROM performance_schema.replication_group_members;" | grep group_replication_applier | head -c1 | wc -c) -eq 1 ]]; then
      break
    fi
    sleep 2s
    echo waiting to join group replication
  done
    echo Joining group replication
    start_node
fi

echo

sudo ufw allow from $ALLOW_IP to any port 33061
sudo ufw allow from $ALLOW_IP to any port 3306

echo setting start on boot
sed -i "#start_on_boot = OFF#start_on_boot = ON#" $CONFIG_FILE
systemctl restart mysql
echo Installation completed

echo '-----------------------------------'
echo "|  SUCCESSFULLY STARTED SERVER ${SERVER_ID}  |"
echo '-----------------------------------'

