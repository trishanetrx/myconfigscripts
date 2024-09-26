import os
import subprocess

def run_command(command):
    """Run a shell command and print the output."""
    try:
        output = subprocess.check_output(command, shell=True, universal_newlines=True)
        print(output)
        return output
    except subprocess.CalledProcessError as e:
        print(f"Command failed: {e}")
        return None

def main():
    # Step 1: Display available disks using lsblk
    print("Listing all block devices:\n")
    run_command("lsblk")
    
    # Step 2: Ask the user for the disk (e.g., /dev/sdX)
    disk = input("Enter the disk on which to run the recovery operation (e.g., /dev/sdc2): ")
    
    # Ensure the user input includes /dev/ prefix
    if not disk.startswith("/dev/"):
        disk = f"/dev/{disk}"
    
    # Confirm the user's choice
    confirm = input(f"You have selected {disk}. Do you want to continue? (yes/no): ").lower()
    if confirm != 'yes':
        print("Operation cancelled by the user.")
        return
    
    # Step 3: Import the cloned volume group and rename it to 'cloned'
    print(f"\nRunning vgimportclone on {disk}...")
    vg_import_result = run_command(f"sudo vgimportclone --basevgname cloned {disk}")
    
    if "Failed to find device" in vg_import_result:
        print(f"\nError: Device {disk} was not found.")
        return

    # Step 4: Activate the cloned volume group
    print("\nActivating cloned volume group...")
    vg_change_result = run_command("sudo vgchange -ay cloned")
    
    if "Volume group \"cloned\" not found" in vg_change_result:
        print("\nError: Cloned volume group not found. Skipping further steps.")
        return
    
    # Step 5: Create mount directory if it doesn't already exist
    mount_dir = "/mnt/damaged_disk"
    if not os.path.exists(mount_dir):
        print(f"\nCreating mount directory {mount_dir}...")
        run_command(f"sudo mkdir {mount_dir}")
    else:
        print(f"\nMount directory {mount_dir} already exists, skipping this step.")
    
    # Step 6: Check if the logical volume exists before repairing
    lv_path = "/dev/cloned/rootlv"
    if not os.path.exists(lv_path):
        print(f"\nError: Logical volume {lv_path} does not exist. Skipping xfs_repair and mount steps.")
        return
    
    # Step 7: Repair the filesystem
    print(f"\nRunning xfs_repair on {lv_path}...")
    run_command(f"sudo xfs_repair {lv_path}")
    
    # Step 8: Mount the repaired logical volume
    print(f"\nMounting the repaired logical volume at {mount_dir}...")
    mount_result = run_command(f"sudo mount -o nouuid {lv_path} {mount_dir}")
    
    if "special device" in mount_result:
        print("\nError: Failed to mount the logical volume. Check if the logical volume exists.")
        return
    
    # Step 9: Inform the user that the process is complete
    print(f"\nDisk mounted successfully. You can now access the filesystem at {mount_dir}.")
    
if __name__ == "__main__":
    main()
