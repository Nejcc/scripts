#!/bin/bash

# Variables
BRIDGE="vmbr0"     # Network bridge to use
CONFIG_FILE="ct_config.txt"

# Function to create a container
create_container() {
    local CTID=$1
    local HOSTNAME=$2
    local IP=$3
    local PASSWORD=$4
    local MEMORY=$5
    local DISK_SIZE=$6
    local START_AT_BOOT=$7
    local TEMPLATE=$8
    local STORAGE=$9

    echo "Creating container $CTID with hostname $HOSTNAME and IP $IP using template $TEMPLATE..."
    echo "Command: pct create $CTID $TEMPLATE --hostname $HOSTNAME --memory $MEMORY --net0 name=eth0,bridge=$BRIDGE,firewall=1,gw=${IP%/*}.1,ip=$IP --rootfs $STORAGE:$DISK_SIZE --password <hidden> --unprivileged 1 --start $START_AT_BOOT"

    pct create $CTID $TEMPLATE --hostname $HOSTNAME --memory $MEMORY --net0 name=eth0,bridge=$BRIDGE,firewall=1,gw=${IP%/*}.1,ip=$IP --rootfs $STORAGE:$DISK_SIZE \
        --password $PASSWORD --unprivileged 1 --start $START_AT_BOOT --ssh-public-keys /root/.ssh/authorized_keys --ostype ubuntu --ignore-unpack-errors

    if [ $? -eq 0 ]; then
        echo "Container $CTID created successfully!"
    else
        echo "Failed to create container $CTID. Please check the Proxmox logs for more details."
        exit 1
    fi
}

# Function to save the configuration
save_configuration() {
    echo "$1" >> $CONFIG_FILE
}

# Function to load the configuration
load_configuration() {
    if [ -f $CONFIG_FILE ]; then
        echo "Found existing configuration file."
        read -rp "Do you want to use the existing configuration? (yes/no): " USE_EXISTING_CONFIG

        if [[ "$USE_EXISTING_CONFIG" == "yes" ]]; then
            while IFS= read -r line; do
                create_container $line
            done < $CONFIG_FILE
            echo "All containers created successfully using existing configuration!"
            exit 0
        else
            rm -f $CONFIG_FILE
            echo "Starting from scratch..."
        fi
    fi
}

# Main function
main() {
    load_configuration

    # Prompt for the common parameters
    read -rp "Enter the nameserver prefix (e.g., gal): " PREFIX
    read -rp "Enter the number of containers to create: " NUM_CONTAINERS
    read -rp "Enter the domain name (e.g., .local): " DOMAIN
    read -rp "Enter the memory size in MB for each container (default 1024): " MEMORY
    MEMORY=${MEMORY:-1024}
    read -rp "Enter the disk size for each container (default 8G): " DISK_SIZE
    DISK_SIZE=${DISK_SIZE:-8G}
    read -rp "Enter the storage pool (e.g., localblock): " STORAGE
    TEMPLATE="/mnt/pve/cephfs/template/cache/jammy-minimal-cloudimg-amd64-root.tar.xz"
    read -rp "Should the containers start at boot? (yes/no): " START_AT_BOOT

    # Ask if the password should be the same for each machine
    read -rp "Should the password be the same for each container? (yes/no): " SAME_PASSWORD
    if [[ "$SAME_PASSWORD" == "yes" ]]; then
        read -rsp "Enter the password for all containers: " PASSWORD
        echo
    fi

    # Ask if the IP should be auto-incremented
    read -rp "Should the IP address be auto-incremented? (yes/no): " AUTO_INCREMENT_IP
    if [[ "$AUTO_INCREMENT_IP" == "yes" ]]; then
        read -rp "Enter the initial IP address (e.g., 192.168.10.71/24): " INITIAL_IP
        IFS='/' read -r BASE_IP SUBNET <<< "$INITIAL_IP"
        IFS='.' read -r IP1 IP2 IP3 IP4 <<< "$BASE_IP"
    fi

    # Convert the yes/no input to a numeric value
    if [[ "$START_AT_BOOT" == "yes" ]]; then
        START_AT_BOOT=1
    else
        START_AT_BOOT=0
    fi

    CONFIG_SUMMARY="Configuration Summary:\n"

    for ((i=0; i<NUM_CONTAINERS; i++)); do
        # Generate the CT ID, hostname, and IP address
        CTID=$((100 + i))
        HOSTNAME="${PREFIX}$(printf "%02d" $CTID)${DOMAIN}"
        
        if [[ "$AUTO_INCREMENT_IP" == "yes" ]]; then
            IP="${IP1}.${IP2}.${IP3}.$((IP4 + i))/${SUBNET}"
        else
            read -rp "Enter the IP address for container $i (e.g., 192.168.10.71/24): " IP
        fi
        
        if [[ "$SAME_PASSWORD" != "yes" ]]; then
            read -rsp "Enter the password for container $i: " PASSWORD
            echo
        fi

        # Save the configuration
        save_configuration "$CTID $HOSTNAME $IP $PASSWORD $MEMORY $DISK_SIZE $START_AT_BOOT $TEMPLATE $STORAGE"

        # Append to the configuration summary
        CONFIG_SUMMARY+="\nCTID: $CTID\nHostname: $HOSTNAME\nIP: $IP\nMemory: $MEMORY MB\nDisk: $DISK_SIZE\nStorage: $STORAGE\nStart at boot: $START_AT_BOOT\nTemplate: $TEMPLATE\n"

        # Create the container
        create_container $CTID $HOSTNAME $IP $PASSWORD $MEMORY $DISK_SIZE $START_AT_BOOT $TEMPLATE $STORAGE
    done

    echo -e "$CONFIG_SUMMARY"
    echo "All containers created successfully!"
}

# Run the main function
main
