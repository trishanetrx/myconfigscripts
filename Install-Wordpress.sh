#!/bin/bash

# Update package index and install required packages
sudo apt update
sudo apt install -y apache2 ghostscript libapache2-mod-php mysql-server php php-bcmath php-curl php-imagick php-intl php-json php-mbstring php-mysql php-xml php-zip

# Create directory for WordPress installation
sudo mkdir -p /srv/www
sudo chown www-data: /srv/www

# Download and extract latest WordPress release
curl https://wordpress.org/latest.tar.gz | sudo -u www-data tar zx -C /srv/www

# Configure Apache virtual host for WordPress
sudo tee /etc/apache2/sites-available/wordpress.conf >/dev/null <<EOF
<VirtualHost *:80>
    DocumentRoot /srv/www/wordpress
    <Directory /srv/www/wordpress>
        Options FollowSymLinks
        AllowOverride Limit Options FileInfo
        DirectoryIndex index.php
        Require all granted
    </Directory>
    <Directory /srv/www/wordpress/wp-content>
        Options FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>
EOF

# Enable the virtual host
sudo a2ensite wordpress.conf

# Restart Apache to apply changes
sudo systemctl restart apache2

# Secure MySQL installation
sudo mysql_secure_installation

# Create MySQL database and user for WordPress
sudo mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE wordpress;
CREATE USER 'wordpress'@'localhost' IDENTIFIED BY 'Power@231*';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost';
FLUSH PRIVILEGES;
QUIT
MYSQL_SCRIPT

# Update WordPress configuration file with database details
sudo -u www-data sed -i 's/database_name_here/wordpress/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/username_here/wordpress/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i "s/password_here/<your-password>/" /srv/www/wordpress/wp-config.php

# Remove salts from WordPress configuration file
sudo -u www-data sed -i '/define(.*SALT.*);/d' /srv/www/wordpress/wp-config.php

# Open WordPress configuration file for further editing
sudo -u www-data nano /srv/www/wordpress/wp-config.php

echo "WordPress installation completed. Please configure your unique phrases in wp-config.php."
