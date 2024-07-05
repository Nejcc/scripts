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
    local SWAP=$7
    local DISK_SIZE=$8
    local START_AT_BOOT=$9

    echo "Creating container $CTID with hostname $HOSTNAME and IP $IP..."
    
    pct create $CTID $TEMPLATE_ID --hostname $HOSTNAME --cores $CORES --memory $RAM --swap $SWAP \
        --net0 name=eth0,bridge=$BRIDGE,ip=$IP --storage $STORAGE --rootfs $DISK_SIZE \
        --password $PASSWORD --onboot $START_AT_BOOT --start 1
    
    echo "Container $CTID created successfully!"
}

# Main function
main() {
    # Prompt for the common parameters
    read -rp "Enter the nameserver prefix (e.g., lb): " PREFIX
    read -rp "Enter the number of containers to create: " NUM_CONTAINERS
    read -rp "Enter the domain name (e.g., .local): " DOMAIN
    read -rp "Enter the number of cores for each container: " CORES
    read -rp "Enter the RAM size in MB for each container: " RAM
    read -rp "Enter the SWAP size in MB for each container: " SWAP
    read -rp "Enter the disk size for each container (e.g., 10G): " DISK_SIZE
    read -rp "Should the containers start at boot? (yes/no): " START_AT_BOOT

    # Convert the yes/no input to a numeric value
    if [[ "$START_AT_BOOT" == "yes" ]]; then
        START_AT_BOOT=1
    else
        START_AT_BOOT=0
    fi

    for ((i=1; i<=NUM_CONTAINERS; i++)); do
        # Generate the CT ID, hostname, and IP address
        CTID=$((100 + i))
        HOSTNAME="${PREFIX}$(printf "%02d" $i)${DOMAIN}"
        read -rp "Enter the IP address for container $i: " IP
        read -rsp "Enter the password for container $i: " PASSWORD
        echo

        # Create the container
        create_container $CTID $HOSTNAME $IP $PASSWORD $CORES $RAM $SWAP $DISK_SIZE $START_AT_BOOT
    done

    echo "All containers created successfully!"
}

# Run the main function
main
