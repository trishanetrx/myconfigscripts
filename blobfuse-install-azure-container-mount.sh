#!/bin/bash

# Function to check and install Blobfuse2
install_blobfuse2() {
  echo "Checking for Blobfuse2..."
  if ! command -v blobfuse2 &> /dev/null; then
    echo "Blobfuse2 not found. Installing..."

    if [ -f /etc/redhat-release ]; then
      # For RHEL
      echo "Detected RHEL-based system."
      sudo yum install -y fuse3 fuse3-devel wget
      wget https://github.com/Azure/azure-storage-fuse/releases/download/blobfuse2-2.4.0/blobfuse2-2.4.0-RHEL-8.2.x86_64.rpm -O blobfuse2.rpm
      sudo rpm -ivh blobfuse2.rpm
    elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then
      # For Ubuntu
      echo "Detected Ubuntu-based system."
      sudo apt update
      sudo apt install -y fuse3 wget
      wget https://github.com/Azure/azure-storage-fuse/releases/download/blobfuse2-2.4.0/blobfuse2-2.4.0-Ubuntu-22.04.x86_64.deb -O blobfuse2.deb
      sudo dpkg -i blobfuse2.deb
    else
      echo "Unsupported OS. Please install Blobfuse2 manually."
      exit 1
    fi
  else
    echo "Blobfuse2 is already installed."
  fi
}

# Function to request storage account details
get_storage_details() {
  echo "Enter the storage account name:"
  read -r storage_account
  echo "Enter the container name:"
  read -r container_name
  echo "Enter the storage account key:"
  read -r storage_key
  echo "Enter the desired folder name under /mnt (e.g., myfolder):"
  read -r folder_name
  mount_dir="/mnt/${folder_name}"
}

# Function to configure and mount Blobfuse2
configure_and_mount() {
  config_file="/etc/blobfuse2/config-${storage_account}.yaml"
  cache_dir="/mnt/blobfuse2_cache_${storage_account}_${container_name}"

  # Create the configuration file
  sudo mkdir -p "$(dirname "$config_file")"
  sudo bash -c "cat > $config_file <<EOF
logging:
  type: syslog
  level: log_info

components:
  - libfuse
  - file_cache
  - azstorage

file_cache:
  path: ${cache_dir}
  timeout-sec: 120
  max-size-mb: 5120

azstorage:
  type: block
  account-name: ${storage_account}
  container: ${container_name}
  mode: key
  account-key: ${storage_key}
EOF"

  # Create directories for cache and mount point
  sudo mkdir -p "${cache_dir}"
  sudo mkdir -p "${mount_dir}"
  sudo chmod 777 "${cache_dir}" "${mount_dir}"

  # Mount the Blob Storage container
  echo "Mounting Blob Storage container at ${mount_dir}..."
  /usr/bin/blobfuse2 mount "${mount_dir}" --config-file="${config_file}"
  if [ $? -eq 0 ]; then
    echo "Mounted successfully at ${mount_dir}."
  else
    echo "Failed to mount the container. Check the logs for details."
  fi
}

# Main script
install_blobfuse2
get_storage_details
configure_and_mount
