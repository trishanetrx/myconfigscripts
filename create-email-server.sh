#!/bin/bash

# Function to display a message and ask for user input
function prompt() {
    read -p "$1: " input
    echo $input
}

# Prompt for basic information
echo "Welcome to the Mail Server Setup Script"

# Get server details
MAIL_DOMAIN=$(prompt "Please enter your mail domain (e.g., example.com)")
HOSTNAME=$(prompt "Please enter your mail server's hostname (e.g., mail.example.com)")
MAIL_USER=$(prompt "Please enter the email administrator username")
MAIL_PASS=$(prompt "Please enter the email administrator password")
MAIL_ALIAS=$(prompt "Please enter email alias (e.g., postmaster@example.com)")

# Update and install required packages
echo "Updating system and installing required packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y postfix postfix-mysql dovecot-core dovecot-imapd dovecot-pop3d dovecot-mysql spamassassin certbot python3-certbot-nginx

# Configure Postfix
echo "Configuring Postfix..."
sudo debconf-set-selections <<< "postfix postfix/mailname string $MAIL_DOMAIN"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
sudo apt install -y postfix

# Postfix configuration
sudo postconf -e "myhostname = $HOSTNAME"
sudo postconf -e "mydomain = $MAIL_DOMAIN"
sudo postconf -e "myorigin = /etc/mailname"
sudo postconf -e "inet_interfaces = all"
sudo postconf -e "inet_protocols = ipv4"
sudo postconf -e "mydestination = $MAIL_DOMAIN, localhost"
sudo postconf -e "smtpd_tls_security_level = may"
sudo postconf -e "smtpd_tls_auth_only = no"
sudo postconf -e "smtp_tls_security_level = may"
sudo postconf -e "smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination"

# Restart Postfix to apply changes
sudo systemctl restart postfix

# Obtain SSL certificate with Certbot
echo "Obtaining SSL certificate for $MAIL_DOMAIN..."
sudo certbot certonly --standalone -d $MAIL_DOMAIN -d $HOSTNAME --agree-tos --non-interactive --email $MAIL_ALIAS

# Configure Postfix for SSL using Certbot certificates
SSL_CERT="/etc/letsencrypt/live/$MAIL_DOMAIN/fullchain.pem"
SSL_KEY="/etc/letsencrypt/live/$MAIL_DOMAIN/privkey.pem"

sudo postconf -e "smtpd_tls_cert_file = $SSL_CERT"
sudo postconf -e "smtpd_tls_key_file = $SSL_KEY"
sudo postconf -e "smtp_tls_cert_file = $SSL_CERT"
sudo postconf -e "smtp_tls_key_file = $SSL_KEY"
sudo postconf -e "smtpd_use_tls = yes"

# Restart Postfix to apply SSL changes
sudo systemctl restart postfix

# Configure Dovecot
echo "Configuring Dovecot..."
sudo sed -i "s/#disable_plaintext_auth = yes/disable_plaintext_auth = no/" /etc/dovecot/conf.d/10-auth.conf
sudo sed -i "s/#mail_location =/mail_location = maildir:~\/Maildir/" /etc/dovecot/conf.d/10-mail.conf
sudo sed -i "s/#ssl = yes/ssl = yes/" /etc/dovecot/conf.d/10-ssl.conf
sudo sed -i "s|#ssl_cert = </etc/ssl/certs/ssl-cert-snakeoil.pem|ssl_cert = <$SSL_CERT|" /etc/dovecot/conf.d/10-ssl.conf
sudo sed -i "s|#ssl_key = </etc/ssl/private/ssl-cert-snakeoil.key|ssl_key = <$SSL_KEY|" /etc/dovecot/conf.d/10-ssl.conf

# Restart Dovecot to apply changes
sudo systemctl restart dovecot

# Add Mail User
echo "Creating email user..."
sudo useradd -m $MAIL_USER
echo "$MAIL_USER:$MAIL_PASS" | sudo chpasswd
sudo mkdir -p /home/$MAIL_USER/Maildir
sudo chown -R $MAIL_USER:$MAIL_USER /home/$MAIL_USER/Maildir
sudo chmod -R 700 /home/$MAIL_USER/Maildir

# Set up SpamAssassin
echo "Configuring SpamAssassin..."
sudo systemctl enable spamassassin
sudo systemctl start spamassassin

# Configure automatic SSL certificate renewal
echo "Configuring automatic SSL certificate renewal..."
sudo systemctl enable certbot.timer

# Final message
echo "Mail server setup complete. You can access the mail service at $HOSTNAME"
echo "Certbot is managing your SSL certificates, and they will automatically renew when necessary."
