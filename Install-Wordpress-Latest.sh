#!/bin/bash

# Update package index and install required packages
sudo apt update
sudo apt install -y apache2 ghostscript libapache2-mod-php mysql-server php php-bcmath php-curl php-imagick php-intl php-mbstring php-mysql php-xml php-zip

# Create directory for WordPress installation
sudo mkdir -p /srv/www
sudo chown www-data: /srv/www

# Download and extract latest WordPress release
curl -o /srv/www/latest.tar.gz https://wordpress.org/latest.tar.gz
sudo -u www-data tar zxvf /srv/www/latest.tar.gz -C /srv/www
rm /srv/www/latest.tar.gz

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

# Enable the virtual host and necessary modules
sudo a2ensite wordpress
sudo a2enmod rewrite
sudo a2dissite 000-default

# Restart Apache to apply changes
sudo systemctl reload apache2

# Start mysql server
sudo systemctl start mysql

# Create or update WordPress database and user
sudo mysql <<MYSQL_SCRIPT
DROP USER IF EXISTS 'wordpress'@'localhost';
CREATE USER 'wordpress'@'localhost' IDENTIFIED BY 'yourpasswordhere*';
CREATE DATABASE IF NOT EXISTS wordpress;
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Copy WordPress configuration file and set database credentials
sudo -u www-data cp /srv/www/wordpress/wp-config-sample.php /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i "s/database_name_here/wordpress/" /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i "s/username_here/wordpress/" /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i "s/password_here/yourpasswordhere*/" /srv/www/wordpress/wp-config.php

# Define config file path
config_file="/srv/www/wordpress/wp-config.php"

# Remove dummy salt lines
sudo sed -i "/put your unique phrase here/d" "$config_file"

# Add new secure keys from WordPress API
WP_SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
awk -v salts="$WP_SALTS" '/\/\* That.s all, stop editing! Happy publishing. \*\//{print salts; print ""; print $0; next}1' "$config_file" > /tmp/wp-config.php
sudo cp /tmp/wp-config.php "$config_file"
sudo rm /tmp/wp-config.php

# Add lines above the specified comment
sudo sed -i "/\/\* That's all, stop editing! Happy publishing. \*\//i \
define('FS_METHOD', 'direct'); \
define('FS_CHMOD_DIR', 0755); \
define('FS_CHMOD_FILE', 0644);" "$config_file"

echo "Lines removed and added to $config_file"

# Restart Apache
sudo systemctl restart apache2

# Instructions to complete the WordPress setup via the web interface
echo "Installation complete. Please finish the setup by visiting http://localhost in your web browser."
