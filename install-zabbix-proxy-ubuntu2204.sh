#!/bin/bash

# Zabbix Proxy Automated Installer (MySQL) for Ubuntu 22.04
# Author: ChatGPT - Verified by Trishane
# Zabbix Version: 7.2

set -e

ZBX_SERVER="135.237.99.175"        # <-- Replace with your Zabbix Server IP
ZBX_PROXY_HOSTNAME="zbx-proxy2"   # <-- Must match exactly in Zabbix frontend
ZBX_DB="zabbix_proxy"
ZBX_DB_USER="zabbix"
ZBX_DB_PASS="@870293100v"         # <-- Use a secure password!

echo "📦 Installing prerequisites..."
sudo apt update
sudo apt install -y wget mysql-server gnupg

echo "🚀 Starting and enabling MySQL service..."
sudo systemctl enable mysql
sudo systemctl start mysql

echo "📥 Downloading Zabbix release package..."
wget https://repo.zabbix.com/zabbix/7.2/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.2+ubuntu22.04_all.deb
sudo dpkg -i zabbix-release_latest_7.2+ubuntu22.04_all.deb
sudo apt update

echo "📥 Installing Zabbix Proxy with MySQL support..."
sudo apt install -y zabbix-proxy-mysql zabbix-sql-scripts

echo "🛠️ Creating Zabbix database and user..."
sudo mysql <<EOF
DROP DATABASE IF EXISTS ${ZBX_DB};
CREATE DATABASE ${ZBX_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS '${ZBX_DB_USER}'@'localhost' IDENTIFIED BY '${ZBX_DB_PASS}';
GRANT ALL PRIVILEGES ON ${ZBX_DB}.* TO '${ZBX_DB_USER}'@'localhost';
SET GLOBAL log_bin_trust_function_creators = 1;
FLUSH PRIVILEGES;
EOF

echo "📄 Importing Zabbix Proxy schema..."
cat /usr/share/zabbix/sql-scripts/mysql/proxy.sql | mysql -u${ZBX_DB_USER} -p${ZBX_DB_PASS} ${ZBX_DB}

echo "📝 Configuring Zabbix Proxy..."
sudo tee /etc/zabbix/zabbix_proxy.conf > /dev/null <<EOF
Server=${ZBX_SERVER}
Hostname=${ZBX_PROXY_HOSTNAME}
LogFile=/var/log/zabbix/zabbix_proxy.log
PidFile=/run/zabbix/zabbix_proxy.pid
DBName=${ZBX_DB}
DBUser=${ZBX_DB_USER}
DBPassword=${ZBX_DB_PASS}
SocketDir=/run/zabbix
LogFileSize=0
Timeout=4
EOF

echo "🚀 Starting and enabling Zabbix Proxy service..."
sudo systemctl enable zabbix-proxy
sudo systemctl restart zabbix-proxy
sudo systemctl status zabbix-proxy --no-pager

echo "✅ Zabbix Proxy installation completed successfully!"
