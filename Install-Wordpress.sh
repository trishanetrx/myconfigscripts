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

# Create WordPress database and user
sudo mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE wordpress;
CREATE USER 'wordpress'@'localhost' IDENTIFIED BY 'Power231*';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Copy WordPress configuration file and set database credentials
sudo -u www-data cp /srv/www/wordpress/wp-config-sample.php /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i "s/database_name_here/wordpress/" /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i "s/username_here/wordpress/" /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i "s/password_here/Power231*/" /srv/www/wordpress/wp-config.php


config_file="/srv/www/wordpress/wp-config.php"

patterns=(
    'define( 'AUTH_KEY',         'put your unique phrase here' );'
    'define( 'SECURE_AUTH_KEY',  'put your unique phrase here' );'
    'define( 'LOGGED_IN_KEY',    'put your unique phrase here' );'
    'define( 'NONCE_KEY',        'put your unique phrase here' );'
    'define( 'AUTH_SALT',        'put your unique phrase here' );'
    'define( 'SECURE_AUTH_SALT', 'put your unique phrase here' );'
    'define( 'LOGGED_IN_SALT',   'put your unique phrase here' );'
    'define( 'NONCE_SALT',       'put your unique phrase here' );'
)

# Loop through the patterns and remove matching lines from the file
for pattern in "${patterns[@]}"; do
    sudo sed -i "/$pattern/d" "$config_file"
done

# Add lines above the specified comment
sudo sed -i "/\/\* That's all, stop editing! Happy publishing. \*\//i \
define('FS_METHOD', 'direct'); \
define('FS_CHMOD_DIR',0755); \
define('FS_CHMOD_FILE',0644);" "$config_file"

echo "Lines removed and added to $config_file"

sudo systemctl restart apache2
