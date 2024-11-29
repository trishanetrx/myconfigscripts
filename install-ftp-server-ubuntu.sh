#!/bin/bash

# Function to handle errors
error_exit() {
    echo "$1" 1>&2
    exit 1
}

# Update the system and install vsftpd
echo "Updating system and installing vsftpd..."
sudo apt update && sudo apt upgrade -y || error_exit "System update failed."
sudo apt install -y vsftpd || error_exit "Failed to install vsftpd."

# Ensure vsftpd starts on boot
echo "Enabling vsftpd service..."
sudo systemctl enable vsftpd || error_exit "Failed to enable vsftpd service."

# Configure vsftpd for FTP user and passive mode
echo "Configuring vsftpd..."
sudo bash -c 'cat <<EOF > /etc/vsftpd.conf
# Allow anonymous FTP login
anonymous_enable=NO

# Enable local users
local_enable=YES
write_enable=YES

# Configure FTP root for user
chroot_local_user=YES

# Configure passive mode
pasv_enable=YES
pasv_min_port=10000
pasv_max_port=10100

# Prevent writable root inside chroot
allow_writeable_chroot=YES

# Log FTP access
xferlog_enable=YES

#Run in standalone mode
listen=YES

# Enable UTF-8 encoding for filenames
utf8_filesystem=YES
EOF' || error_exit "Failed to write vsftpd configuration."

# Restart vsftpd to apply changes
echo "Restarting vsftpd..."
sudo systemctl restart vsftpd || error_exit "Failed to restart vsftpd."

# Create FTP user
echo "Creating FTP user 'ftpuser'..."
sudo useradd -m ftpuser || error_exit "Failed to create ftpuser."
echo "Setting password for ftpuser..."
echo "ftpuser:yourpassword" | sudo chpasswd || error_exit "Failed to set password for ftpuser."

# Create FTP directories and set permissions
echo "Creating FTP directory structure..."
sudo mkdir -p /home/ftpuser/ftp/upload || error_exit "Failed to create FTP directories."
sudo chown -R ftpuser:ftpuser /home/ftpuser/ftp || error_exit "Failed to set ownership on FTP directories."
sudo chmod 755 /home/ftpuser/ftp || error_exit "Failed to set permissions on FTP directory."
sudo chmod 777 /home/ftpuser/ftp/upload || error_exit "Failed to set permissions on upload directory."

# Allow FTP traffic through the firewall
echo "Configuring firewall..."
sudo ufw allow 20/tcp || error_exit "Failed to allow FTP data port 20."
sudo ufw allow 21/tcp || error_exit "Failed to allow FTP command port 21."
sudo ufw allow 10000:10100/tcp || error_exit "Failed to allow passive FTP ports."
sudo ufw reload || error_exit "Failed to reload firewall."

# Check if firewall is enabled
if sudo ufw status | grep -q "Status: inactive"; then
    echo "Firewall is inactive, enabling it..."
    sudo ufw enable || error_exit "Failed to enable firewall."
fi

# Restart vsftpd to ensure everything is properly configured
echo "Restarting vsftpd for final configuration..."
sudo systemctl restart vsftpd || error_exit "Failed to restart vsftpd after configuration."

# Display the FTP user and permissions
echo "FTP server setup complete. Here's a summary:"
echo "User: ftpuser"
echo "Password: yourpassword"
echo "Home directory: /home/ftpuser/ftp"
echo "Upload directory: /home/ftpuser/ftp/upload"
echo "Permissions: 755 on /home/ftpuser/ftp and 777 on /home/ftpuser/ftp/upload"

echo "FTP server is ready to use. You can connect using the following credentials:"
echo "Host: localhost"
echo "Username: ftpuser"
echo "Password: yourpassword"
