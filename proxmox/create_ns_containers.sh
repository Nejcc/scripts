#!/bin/bash

# Variables
TEMPLATE_ID="100"  # ID of the template, assuming a Debian template
BRIDGE="vmbr0"     # Network bridge to use
STORAGE="local-lvm"  # Storage pool

# Function to create a container
create_container() {
    local CTID=$1
    local HOSTNAME=$2
    local IP=$3
    local PASSWORD=$4
    local CORES=$5
    local RAM=$6
    local START_AT_BOOT=$7
    local DISK_SIZE=$8

    echo "Creating container $CTID with hostname $HOSTNAME and IP $IP..."
    
    pct create $CTID $TEMPLATE_ID --hostname $HOSTNAME --cores $CORES --memory $RAM \
        --net0 name=eth0,bridge=$BRIDGE,ip=$IP --storage $STORAGE --rootfs $DISK_SIZE \
        --password $PASSWORD --onboot $START_AT_BOOT --start 1
    
    echo "Container $CTID created successfully!"
}

# Main function
main() {
    # Prompt for the number of containers
    read -rp "Enter the number of containers to create: " NUM_CONTAINERS

    for ((i=1; i<=NUM_CONTAINERS; i++)); do
        # Prompt for the CT ID, hostname, IP address, password, cores, RAM, and whether to start at boot
        read -rp "Enter the CT ID for container $i: " CTID
        read -rp "Enter the hostname for container $i: " HOSTNAME
        read -rp "Enter the IP address for container $i: " IP
        read -rsp "Enter the password for container $i: " PASSWORD
        echo
        read -rp "Enter the number of cores for container $i: " CORES
        read -rp "Enter the RAM size in MB for container $i: " RAM
        read -rp "Enter the disk size for container $i (e.g., 10G): " DISK_SIZE
        read -rp "Should the container start at boot? (yes/no): " START_AT_BOOT

        # Convert the yes/no input to a numeric value
        if [[ "$START_AT_BOOT" == "yes" ]]; then
            START_AT_BOOT=1
        else
            START_AT_BOOT=0
        fi

        # Create the container
        create_container $CTID $HOSTNAME $IP $PASSWORD $CORES $RAM $START_AT_BOOT $DISK_SIZE
    done

    echo "All containers created successfully!"
}

# Run the main function
main
