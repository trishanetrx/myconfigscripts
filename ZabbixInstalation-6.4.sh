#!/bin/bash

# --- Variables ---
ZABBIX_VERSION="6.4"
MYSQL_ROOT_USER="root"

echo "Enter database password for 'zabbix' user:"
read -s DB_PASSWORD

# --- Install Zabbix repo ---
wget https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_${ZABBIX_VERSION}+ubuntu22.04_all.deb
sudo dpkg -i zabbix-release_latest_${ZABBIX_VERSION}+ubuntu22.04_all.deb
sudo apt update

# --- Install Zabbix server, frontend, agent ---
sudo apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

# --- Install MySQL Server ---
sudo apt install -y mysql-server
sudo systemctl start mysql

# --- Create Zabbix Database and User ---
sudo mysql <<EOF
CREATE DATABASE zabbix character set utf8mb4 collate utf8mb4_bin;
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
FLUSH PRIVILEGES;
SET GLOBAL log_bin_trust_function_creators = 1;
EOF

# --- Import Zabbix Initial Schema and Data ---
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -p${DB_PASSWORD} zabbix

# --- Update Zabbix server configuration ---
sudo sed -i "s/^# DBHost=.*/DBHost=localhost/" /etc/zabbix/zabbix_server.conf
sudo sed -i "s/^# DBName=.*/DBName=zabbix/" /etc/zabbix/zabbix_server.conf
sudo sed -i "s/^# DBUser=.*/DBUser=zabbix/" /etc/zabbix/zabbix_server.conf
sudo sed -i "s/^# DBPassword=.*/DBPassword=${DB_PASSWORD}/" /etc/zabbix/zabbix_server.conf

# --- Restart Zabbix Server ---
sudo systemctl restart zabbix-server
sudo systemctl enable zabbix-server
sudo systemctl restart apache2

echo "✅ Zabbix Server installation and setup completed."
echo "Access your frontend at: http://your-server-ip/zabbix"
echo ${DB_PASSWORD}
