#!/bin/bash

# Function to handle errors
error_exit() {
    echo "[ERROR] $1"
    exit 1
}

# Ensure script runs as root
if [ "$(id -u)" -ne 0 ]; then
    error_exit "This script must be run as root!"
fi

# Ensure necessary commands are available
if ! command -v wget &> /dev/null; then
    echo "Installing wget..."
    sudo dnf install wget -y || error_exit "Failed to install wget."
fi

if ! command -v keytool &> /dev/null; then
    echo "Installing OpenJDK for keytool..."
    sudo dnf install java-17-openjdk -y || error_exit "Failed to install OpenJDK for keytool."
fi

# Ensure Java is installed
if ! java -version 2>/dev/null | grep -q "openjdk"; then
    echo "Java is not installed. Installing Java..."
    sudo dnf update -y || error_exit "Failed to update system."
    sudo dnf install java-17-openjdk -y || error_exit "Failed to install OpenJDK."
else
    echo "Java is already installed."
fi

# Create the jvmapps user if not already existing
if ! id -u jvmapps >/dev/null 2>&1; then
    echo "Creating user 'jvmapps'..."
    sudo useradd -m jvmapps || error_exit "Failed to create user 'jvmapps'."
else
    echo "User 'jvmapps' already exists."
fi

# Set up WireMock directory
WIREMOCK_DIR="/opt/wiremock"
if [ -d "$WIREMOCK_DIR" ]; then
    echo "WireMock directory already exists at $WIREMOCK_DIR."
else
    echo "Creating WireMock directory..."
    sudo mkdir -p "$WIREMOCK_DIR" || error_exit "Failed to create /opt/wiremock directory."
    sudo chown jvmapps:jvmapps "$WIREMOCK_DIR" || error_exit "Failed to set permissions on /opt/wiremock."
fi

# Download the correct WireMock standalone JAR
WIREMOCK_JAR="$WIREMOCK_DIR/wiremock-standalone-3.9.1.jar"
if [ -f "$WIREMOCK_JAR" ]; then
    echo "WireMock standalone JAR already exists."
else
    echo "Downloading the correct WireMock standalone JAR..."
    sudo wget -O "$WIREMOCK_JAR" https://repo1.maven.org/maven2/org/wiremock/wiremock-standalone/3.9.1/wiremock-standalone-3.9.1.jar || error_exit "Failed to download WireMock standalone JAR."
fi

# Set up keystore using keytool if not already created
KEYSTORE="$WIREMOCK_DIR/wiremock.jks"
if [ -f "$KEYSTORE" ]; then
    echo "Keystore already exists. Verifying..."
    sudo keytool -list -v -keystore "$KEYSTORE" -storepass Fazil071 || error_exit "Failed to verify keystore."
else
    echo "Setting up keystore..."
    sudo keytool -genkeypair -alias wiremock -keyalg RSA -keysize 2048 -keystore "$KEYSTORE" -storepass Fazil071 -dname "CN=localhost, OU=IT, O=MyCompany, L=City, ST=State, C=US" || error_exit "Failed to create keystore."
fi

# Set permissions for the WireMock files and directories
echo "Setting permissions for WireMock files..."
sudo chown -R root:root "$WIREMOCK_DIR" || error_exit "Failed to change ownership of WireMock directory."
sudo chmod 755 "$WIREMOCK_DIR" || error_exit "Failed to set permissions on WireMock directory."
sudo chmod 644 "$WIREMOCK_JAR" || error_exit "Failed to set permissions on WireMock JAR."
sudo chmod 600 "$KEYSTORE" || error_exit "Failed to set permissions on keystore."

# Ensure port 8080 is not already in use
if sudo lsof -i :8080 &> /dev/null; then
    error_exit "Port 8080 is already in use. Please free the port or use a different one."
fi

# Create WireMock systemd service file
SERVICE_FILE="/etc/systemd/system/wiremock.service"
if [ -f "$SERVICE_FILE" ]; then
    echo "WireMock systemd service file already exists."
else
    echo "Creating systemd service file for WireMock..."
    sudo bash -c 'cat > /etc/systemd/system/wiremock.service <<EOF
[Unit]
Description=WireMock Server
After=network.target

[Service]
User=root
WorkingDirectory=/opt/wiremock
Environment="JAVA_OPTS=-Djavax.net.ssl.keyStore=/opt/wiremock/wiremock.jks -Djavax.net.ssl.keyStorePassword=Fazil071"
ExecStart=/usr/bin/java \$JAVA_OPTS -jar /opt/wiremock/wiremock-standalone-3.9.1.jar --https-port 443 --global-response-templating --verbose
Restart=on-failure
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF' || error_exit "Failed to create WireMock systemd service file."
fi

# Reload systemd daemon and start the WireMock service
echo "Reloading systemd daemon and starting WireMock service..."
sudo systemctl daemon-reload || error_exit "Failed to reload systemd daemon."
sudo systemctl enable wiremock.service || error_exit "Failed to enable WireMock service."
sudo systemctl start wiremock.service || error_exit "Failed to start WireMock service."

# Check status of the WireMock service
sudo systemctl status wiremock.service --no-pager || error_exit "WireMock service failed to start."

echo "WireMock installation and setup completed successfully!"
