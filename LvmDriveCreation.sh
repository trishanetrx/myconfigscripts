#!/bin/bash

# Create a directory to store log files if it doesn't exist
log_dir="lvm_logs"
if [ ! -d "$log_dir" ]; then
    mkdir "$log_dir"
fi

# Log file paths
disk_log="$log_dir/disk.log"
vg_name_log="$log_dir/vg_name.log"
lv_name_log="$log_dir/lv_name.log"
lv_size_log="$log_dir/lv_size.log"
mount_directory_log="$log_dir/mount_directory.log"

# Display available disks and prompt the user to select a disk for LVM setup
lsblk
echo "Please select a disk from the list above (e.g., sda, sdb, etc.): "
read disk
echo "Selected disk: $disk" >> "$disk_log"

# Check if the disk has a partition
if [ -n "$(lsblk -n -o NAME -b /dev/$disk | sed -n 2p)" ]; then
    echo "A partition already exists on disk $disk."
    # Check if a volume group is already created on the partition
    if pvs /dev/${disk}1 &> /dev/null; then
        echo "A volume group is already created on the partition /dev/${disk}1."
        # Skip partition creation and volume group creation
    else
        echo "No volume group is created on the partition /dev/${disk}1."
        # Proceed with creating a volume group
    fi
else
    echo "Creating a new partition for the entire space on $disk."
    echo -e "n\np\n1\n\n\nw" | fdisk /dev/$disk
    # Ensure the partition is recognized before proceeding
    partprobe /dev/$disk
    # Resize the physical volume
    pvcreate /dev/${disk}1
    # Create a volume group
    echo "Please enter a name for the volume group (e.g., VGdata1): "
    read vg_name
    echo "Volume group name: $vg_name" >> "$vg_name_log"
    vgcreate $vg_name /dev/${disk}1
fi

# Create a logical volume
echo "Please enter a name for the logical volume (e.g., LVdata1): "
read lv_name
echo "Logical volume name: $lv_name" >> "$lv_name_log"

# Check for existing volume groups
existing_vgs=$(vgs --options vg_name --noheadings)
if [ -n "$existing_vgs" ]; then
    echo "Existing Volume Groups:"
    echo "$existing_vgs"
    echo "Please select an existing volume group for the logical volume: "
    read selected_vg
    vg_name=$selected_vg
else
    echo "No existing volume groups found. Please create a volume group first."
    exit 1
fi

echo "Do you want to use the whole disk for the logical volume? (yes/no): "
read use_whole_disk

if [[ $use_whole_disk == "yes" ]]; then
    lvcreate -l 100%FREE -n $lv_name $vg_name
else
    echo "Please enter the size for the logical volume (e.g., 10G, 100M, etc.): "
    read lv_size
    echo "Logical volume size: $lv_size" >> "$lv_size_log"
    lvcreate -L $lv_size -n $lv_name $vg_name
fi

# Create ext4 file system
lv_path="/dev/$vg_name/$lv_name"
mkfs.ext4 $lv_path

# Prompt the user to enter a mount directory name
echo "Please enter a name for the directory to mount the logical volume (e.g., data01): "
read mount_directory
echo "Mount directory name: $mount_directory" >> "$mount_directory_log"

# Create the directory to mount the logical volume
mkdir /$mount_directory

# Mount the logical volume as read-write
mount $lv_path /$mount_directory

# Add entry to /etc/fstab for automatic mounting at boot
echo "$lv_path   /$mount_directory   ext4   defaults   0 0" >> /etc/fstab

echo "LVM setup completed successfully!"
