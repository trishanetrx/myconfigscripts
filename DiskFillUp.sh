#!/bin/bash
# Function to monitor progress
monitor_progress() {
    while true; do
        sleep 10 # Adjust the interval as needed
        free_space=$(df -h /mnt/test | awk 'NR==2 {print $4}') # Free space in the filesystem
        used_percentage=$(df -h /mnt/test | awk 'NR==2 {print $5}' | cut -d'%' -f1) # Used percentage
        echo "Free Space: $free_space"
        echo "Used Percentage: $used_percentage%"
        if [ $used_percentage -ge 95 ]; then
            echo "Used percentage reached 95%, stopping script..."
            pkill -P $$ dd
            break
        fi
    done
}
# Create directory if not exists
mkdir -p /mnt/test
# Fill up the drive with dummy data
dd if=/dev/urandom bs=90M | dd of=/mnt/test/fill_file &
# Monitor progress
monitor_progress
