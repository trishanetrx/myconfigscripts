#!/bin/bash

LOG_FILE="/var/log/blobfuse2-mount.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===== Starting Blobfuse2 Setup ====="

# Function to check and install Blobfuse2
install_blobfuse2() {
  echo "Checking for Blobfuse2..."
  if ! command -v blobfuse2 &> /dev/null; then
    echo "Blobfuse2 not found. Installing..."

    if [ -f /etc/redhat-release ]; then
      echo "Detected RHEL-based system."
      sudo yum install -y fuse3 fuse3-devel wget
      wget https://github.com/Azure/azure-storage-fuse/releases/download/blobfuse2-2.4.0/blobfuse2-2.4.0-RHEL-8.2.x86_64.rpm -O blobfuse2.rpm
      sudo rpm -ivh blobfuse2.rpm
    elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then
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

# Create genrocket user and group
setup_genrocket_user() {
  if ! id "genrocket" &>/dev/null; then
    echo "Creating user and group 'genrocket'..."
    sudo groupadd genrocket
    sudo useradd -m -g genrocket genrocket
  else
    echo "User 'genrocket' already exists."
  fi
}

# Get storage details
get_storage_details() {
  echo "Enter the storage account name:"
  read -r storage_account
  echo "Enter the container name:"
  read -r container_name
  echo "Enter the storage account key (it will not be stored in config file):"
  read -r -s storage_key
  echo "DEBUG: Storage Key -> ${storage_key}"
  echo "Enter the desired folder name under root (e.g., myfolder):"
  read -r folder_name
  mount_dir="/${folder_name}"
  config_file="/home/genrocket/config-${storage_account}-${container_name}.yaml"
  service_file="/etc/systemd/system/blobfuse2-${storage_account}-${container_name}.service"

  export AZURE_STORAGE_KEY="${storage_key}"
  echo "DEBUG: AZURE_STORAGE_KEY is now set."
}

echo "user_allow_other" | sudo tee -a /etc/fuse.conf

# Create and save config file
configure_blobfuse2() {
  sudo mkdir -p "$(dirname "$config_file")"

  if [ -f "$config_file" ]; then
    echo "Config already exists at $config_file — reusing."
  else
    echo "Creating new config at $config_file"
    sudo bash -c "cat > $config_file" <<EOF
logging:
  type: syslog
  level: log_info

components:
 - libfuse
 - stream
 - attr_cache
 - azstorage

libfuse:
 attribute-expiration-sec: 0
 entry-expiration-sec: 0
 negative-entry-expiration-sec: 0
 direct-io: true

stream:
 block-size-mb: 64
 max-buffers: 64
 buffer-size-mb: 64
 file-caching: false

attr_cache:
 timeout-sec: 0
 no-symlinks: false

azstorage:
  type: adls
  account-name: ${storage_account}
  container: ${container_name}
  mode: key
  account-key: ${storage_key}
EOF

    sudo chown genrocket:genrocket "$config_file"
    sudo chmod 600 "$config_file"
  fi

  sudo mkdir -p "${mount_dir}"
  sudo chown genrocket:genrocket "${mount_dir}"
  sudo chmod 770 "${mount_dir}"
}

# Mount temporarily
mount_once() {
  echo "Mounting Blob Storage container at ${mount_dir} (temporary)..."
  sudo AZURE_STORAGE_KEY="${storage_key}" /usr/bin/blobfuse2 mount "${mount_dir}" --config-file="${config_file}"

  if [ $? -eq 0 ]; then
    echo "Successfully mounted at ${mount_dir}. (Temporary, will unmount on reboot)"
  else
    echo "Failed to mount the container. Check logs."
  fi
}

# Persistent mount
configure_and_persist_mount() {
  mount_once
  setup_persistent_mount
}

# Create systemd unit if not exists
setup_persistent_mount() {
  if [ -f "$service_file" ]; then
    echo "Systemd service already exists at $service_file — reusing."
  else
    echo "Creating systemd unit at $service_file"
    sudo bash -c "cat > $service_file" <<EOF
[Unit]
Description=Blobfuse2 mount for ${storage_account}/${container_name}
After=network-online.target

[Service]
User=root
Environment=AZURE_STORAGE_KEY=${AZURE_STORAGE_KEY}
ExecStartPre=/bin/bash -c 'if ! mountpoint -q ${mount_dir}; then exit 0; fi'
ExecStart=/bin/bash -c 'if ! mountpoint -q ${mount_dir}; then /usr/bin/blobfuse2 mount ${mount_dir} -o allow_other --config-file=${config_file}; fi'
ExecStopPost=/bin/bash -c 'fusermount3 -u ${mount_dir} || true'
Restart=always
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
  fi

  sudo systemctl daemon-reload
  sudo systemctl enable "$(basename "$service_file")"
  sudo systemctl start "$(basename "$service_file")"

  echo "Persistent mount configured via systemd."
}

# Cleanup
unmount_and_cleanup() {
  echo "Unmounting Blobfuse2 from ${mount_dir}..."

  if [ -f "$service_file" ]; then
    sudo systemctl stop "$(basename "$service_file")"
    sudo systemctl disable "$(basename "$service_file")"
    sudo rm -f "$service_file"
    sudo systemctl daemon-reload
  fi

  if mountpoint -q "${mount_dir}"; then
    echo "Unmounting ${mount_dir}..."
    sudo fusermount3 -u "${mount_dir}" || true
  else
    echo "${mount_dir} is not currently mounted — skipping unmount."
  fi

  sudo rm -rf "${mount_dir}"
  sudo rm -f "${config_file}"

  echo "Blobfuse2 unmounted and cleaned up:"
  echo "- Removed mount directory: ${mount_dir}"
  echo "- Removed config file: ${config_file}"
  echo "- Removed service file: ${service_file}"
}

# Main menu
echo "Choose an action: "
echo "[1] Mount & Persist (Startup Enabled)"
echo "[2] Unmount & Cleanup"
echo "[3] Mount Only (No Persistence)"
read -r action

case $action in
  1)
    install_blobfuse2
    setup_genrocket_user
    get_storage_details
    configure_blobfuse2
    configure_and_persist_mount
    ;;
  2)
    setup_genrocket_user
    get_storage_details
    unmount_and_cleanup
    ;;
  3)
    install_blobfuse2
    setup_genrocket_user
    get_storage_details
    configure_blobfuse2
    mount_once
    ;;
  *)
    echo "Invalid option. Exiting."
    exit 1
    ;;
esac
