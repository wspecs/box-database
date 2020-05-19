#!/bin/bash

source /etc/wspecs/global.conf
source /etc/wspecs/functions.sh

install_once mysql-server

if [ -f "~/.my.cnf" ]; then
  echo MySQL login is already configured
else
  echo "Setting up MYSQL login"
  NEW_PASSWORD=$(openssl rand -base64 36 | tr -d "=+/" | cut -c1-32)
  mysql -e "SET PASSWORD FOR root@localhost = PASSWORD('$NEW_PASSWORD')"
  mysql -e "DELETE FROM mysql.user WHERE User=''"
  mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
  mysql -e "DROP DATABASE IF EXISTS test"
  mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
  mysql -e "FLUSH PRIVILEGES"

  echo "Creating mysql config"
  cat > ~/.my.cnf <<EOL
[mysql]
user=root
password=$NEW_PASSWORD
EOL
  chmod 0600 ~/.my.cnf
fi

DB_ROLE="${DB_ROLE:-master}"
DB_SERVER_ID="${DB_SERVER_ID:-1}"

if [ "$DB_ROLE" == "master" ]; then
  cp ./my.cnf /etc/mysql/my.cnf
  add_config server-id=$DB_SERVER_ID /etc/mysql/my.cnf

  if [ ! -f "~/.db.replication.passport" ]; then
    REPLICATION_PASSPORT=$(openssl rand -base64 36 | tr -d "=+/" | cut -c1-32)
    add_config passport=$REPLICATION_PASSPORT ~/.db.replication.passport
  fi

  mkdir -p /var/log/mysql
  chown -R mysql:mysql /var/log/mysql
  mysql -e "GRANT REPLICATION SLAVE ON *.* TO 'slave_user'@'%' IDENTIFIED BY '$REPLICATION_PASSPORT'"
  mysql -e "FLUSH PRIVILEGES;"
  sudo service mysql restart
fi
