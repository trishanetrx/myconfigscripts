#!/bin/bash

# Update and install required dependencies
echo "Installing required packages..."
sudo apt update
sudo apt install -y apache2 php php-zip php-mbstring php-curl php-json unzip

# Define the target path for Tiny File Manager
TINY_DIR="/var/www/html/tinyfilemanager"
FTP_ROOT_DIR="/home/new-folder"

# Download Tiny File Manager zip
echo "Downloading Tiny File Manager..."
wget https://github.com/prasathmani/tinyfilemanager/releases/download/v2.6/tinyfilemanager.zip -P /tmp

# Unzip Tiny File Manager to the web directory
echo "Extracting Tiny File Manager..."
sudo unzip /tmp/tinyfilemanager.zip -d /var/www/html/

# Set the correct file permissions
echo "Setting file permissions..."
sudo chown -R www-data:www-data $TINY_DIR
sudo chmod -R 755 $TINY_DIR

# Edit the filemanager.php to set the root path
echo "Configuring Tiny File Manager..."

# Set the root path in filemanager.php
sudo sed -i "s|defined('FM_ROOT_PATH') || define('FM_ROOT_PATH', '/var/www/html');|defined('FM_ROOT_PATH') || define('FM_ROOT_PATH', '$FTP_ROOT_DIR');|" $TINY_DIR/filemanager.php

# Optional: Enable authentication by editing the file and adding users
# Replace this with your preferred users and passwords
echo "Configuring user authentication..."
sudo sed -i "s/\$use_auth = false;/\$use_auth = true;/" $TINY_DIR/filemanager.php
sudo sed -i "s/\$auth_users = array();/\$auth_users = array('admin' => '\$2y\$10\$Q1SxPiXjA39oSzPnAQU0xew20lkDmh6t6sPHkcREa1Z2fKq23g9JX6j6tOw', 'user' => '\$2y\$10\$Fg6Dz8oH9fPoZ2jJan5tZuv6Z4Kp7avtQ9bDfrdRntXtPeiMAZyGO');/" $TINY_DIR/filemanager.php

# Restart Apache to apply changes
echo "Restarting Apache server..."
sudo systemctl restart apache2

# Final message
echo "Tiny File Manager setup complete. You can access it at http://your_server_ip/tinyfilemanager/filemanager.php"
