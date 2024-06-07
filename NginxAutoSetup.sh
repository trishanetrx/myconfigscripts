#!/bin/bash

# Check if Nginx is installed
echo -e "\e[34mCheck if Nginx is installed\e[0m"

if command -v nginx &>/dev/null; then
    echo -e "\e[32m***Nginx is already installed.***\e[0m"
else
    # Detect the operating system
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_NAME=$NAME
    elif [[ -f /etc/lsb-release ]]; then
        source /etc/lsb-release
        OS_NAME=$DISTRIB_ID
    else
        echo -e "\e[31m***Unsupported operating system.***\e[0m"
        exit 1
    fi

    # Install Nginx based on the detected OS
    case $OS_NAME in
        Ubuntu|Debian)
            sudo apt-get update
            sudo apt-get install nginx -y
            ;;
        CentOS|RHEL)
            sudo yum install epel-release -y
            sudo yum install nginx -y
            ;;
        *)
            echo "***Unsupported operating system.***"
            exit 1
            ;;
    esac

    # Start Nginx service
    sudo systemctl start nginx
    sudo systemctl enable nginx
    echo "Nginx installed and started."
fi

# Prompt the user for server URL and port
read -p "Enter the server URL (e.g., test.test.com): " WEBSITE_NAME
read -p "Enter the port being forwarded for the main location (e.g., 3000): " MAIN_PORT

# Define the backend address for the main location
MAIN_BACKEND_ADDRESS="http://127.0.0.1:$MAIN_PORT"

# Prompt the user if they want to create a second location block
read -p "Do you want to create a second location block? (yes/no): " CREATE_SECOND_BLOCK

# If creating a second location block, prompt for the path and port
if [[ "$CREATE_SECOND_BLOCK" == "yes" ]]; then
    read -p "Enter the path for the second location block (e.g., /ws): " SECOND_PATH
    read -p "Enter the port being forwarded for the second location (e.g., 4000): " SECOND_PORT
    SECOND_BACKEND_ADDRESS="http://127.0.0.1:$SECOND_PORT"
fi

# Step 1: Create Nginx configuration file
cat <<EOF > /etc/nginx/sites-available/$WEBSITE_NAME
server {
    listen 80;
    server_name $WEBSITE_NAME;

    location / {
        proxy_pass $MAIN_BACKEND_ADDRESS;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

EOF

# Add a second location block if requested
if [[ "$CREATE_SECOND_BLOCK" == "yes" ]]; then
    cat <<EOF >> /etc/nginx/sites-available/$WEBSITE_NAME
    location $SECOND_PATH {
        proxy_pass $SECOND_BACKEND_ADDRESS;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
EOF
fi

# Close the server block
echo "}" >> /etc/nginx/sites-available/$WEBSITE_NAME

# Step 2: Create symbolic link
ln -s /etc/nginx/sites-available/$WEBSITE_NAME /etc/nginx/sites-enabled/

# Step 3: Reload Nginx
sudo systemctl reload nginx

echo "***Nginx configuration for $WEBSITE_NAME created and linked. Nginx reloaded.***"
