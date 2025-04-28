#!/bin/bash

# Stop on any error
set -e

# 1. Backup Database
echo "Backing up Zabbix database..."
mysqldump -u root -p zabbix > /home/trishane/zabbix_db_backup_$(date +%F).sql

# 2. Backup Configurations
echo "Backing up Zabbix and Apache configurations..."
sudo tar czvf /home/trishane/zabbix_conf_backup_$(date +%F).tar.gz /etc/zabbix /etc/apache2 /usr/share/zabbix

# 3. Remove Old Repo
echo "Removing old Zabbix repository..."
sudo apt remove -y zabbix-release

# 4. Add New Zabbix 7.2 Repo
echo "Adding Zabbix 7.2 repository..."
wget -q https://repo.zabbix.com/zabbix/7.2/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.2+ubuntu22.04_all.deb
sudo dpkg -i zabbix-release_latest_7.2+ubuntu22.04_all.deb
sudo apt update

# 5. Upgrade Zabbix Packages
echo "Upgrading Zabbix server, agent, frontend, and scripts..."
# Auto-answer "keep the local version" (N) for config prompts
sudo DEBIAN_FRONTEND=noninteractive apt install --only-upgrade -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

# 6. Stop Zabbix Server
echo "Stopping Zabbix server..."
sudo systemctl stop zabbix-server

# 7. Run Database Upgrade
echo "Starting Zabbix server manually to upgrade database..."
sudo /usr/sbin/zabbix_server -c /etc/zabbix/zabbix_server.conf -f &
ZABBIX_PID=$!

# Wait until upgrade messages appear (sleep for 60 seconds to allow upgrade)
echo "Waiting 60 seconds for database upgrade to complete..."
sleep 60

# Kill foreground server (safe after 60 seconds)
sudo kill $ZABBIX_PID
sleep 5

# 8. Start Zabbix Server Normally
echo "Starting Zabbix server and Apache properly..."
sudo systemctl start zabbix-server
sudo systemctl restart apache2

# 9. Done
echo "✅ Upgrade from Zabbix 6.4 to 7.2 Completed Successfully!"
