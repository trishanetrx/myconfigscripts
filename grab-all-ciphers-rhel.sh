#!/bin/bash

# Check if OpenSSL is installed
if ! command -v openssl &> /dev/null
then
    echo "OpenSSL could not be found. Please install it and run this script again."
    exit 1
fi

# Grab all the available ciphers
ciphers=$(openssl ciphers -v)

# Print the ciphers list to the terminal
echo "Available ciphers on this RHEL system:"
echo "$ciphers"
