#!/bin/bash

# Exit on any error
set -e

# Update package lists
apt update

# Install Apache and PHP
apt install -y apache2
apt install -y php php-{cgi,common,mbstring,net-socket,gd,xml-util,mysql,bcmath,imap,snmp}
apt install -y libapache2-mod-php

# Download and install Zabbix repository
wget https://repo.zabbix.com/zabbix/7.2/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.2+ubuntu24.04_all.deb
dpkg -i zabbix-release_latest_7.2+ubuntu24.04_all.deb

# Update package lists again after adding Zabbix repo
apt update

# Install Zabbix components
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

# Install MySQL server
apt install -y mysql-server

# Configure MySQL for Zabbix
mysql -uroot <<EOF
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'Pass@231vv';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
SET GLOBAL log_bin_trust_function_creators = 1;
EOF

# Import initial Zabbix database schema
zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p'Pass@231vv' zabbix

# Reset MySQL setting
mysql -uroot <<EOF
SET GLOBAL log_bin_trust_function_creators = 0;
EOF

# Update Zabbix configuration
sed -i 's/# DBPassword=/DBPassword=Pass@231vv/' /etc/zabbix/zabbix_server.conf

# Restart and enable services
systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2

echo "Zabbix installation and configuration completed successfully!"
