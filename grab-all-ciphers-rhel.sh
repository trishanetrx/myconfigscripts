#!/bin/bash

# Function to get the server name
get_server_name() {
    hostname
}

# Check if OpenSSL is installed
if ! command -v openssl &> /dev/null
then
    echo "OpenSSL could not be found. Please install it and run this script again."
    exit 1
fi

# Grab the server name
server_name=$(get_server_name)

# Grab all the available ciphers
ciphers=$(openssl ciphers -v)

# Print the server name and the ciphers list to the terminal
echo "Server Name: $server_name"
echo "Available ciphers on this RHEL system:"
echo "$ciphers"

