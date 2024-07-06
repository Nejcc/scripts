#!/bin/bash

# Variables
BRIDGE="vmbr0"     # Network bridge to use
CONFIG_FILE="ct_config.txt"

# Function to create a container
create_container() {
    local CTID=$1
    local HOSTNAME=$2
    local STORAGE=$3
    local DISK_SIZE=$4
    local MEMORY=$5
    local SWAP=$6
    local CORES=$7
    local IP=$8

    echo "Creating container $CTID with hostname $HOSTNAME and IP $IP..."
    echo "Command: pct create $CTID local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst --hostname $HOSTNAME --storage $STORAGE --rootfs $STORAGE:$DISK_SIZE --memory $MEMORY --swap $SWAP --cores $CORES --net0 name=eth0,bridge=$BRIDGE,ip=$IP"

    pct create $CTID local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst --hostname $HOSTNAME --storage $STORAGE --rootfs $STORAGE:$DISK_SIZE --memory $MEMORY --swap $SWAP --cores $CORES --net0 name=eth0,bridge=$BRIDGE,ip=$IP

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
    read -rp "Enter the nameserver prefix (e.g., lb): " PREFIX
    read -rp "Enter the number of containers to create: " NUM_CONTAINERS
    read -rp "Enter the domain name (e.g., .local): " DOMAIN
    read -rp "Enter the memory size in MB for each container (default 2048): " MEMORY
    MEMORY=${MEMORY:-2048}
    read -rp "Enter the SWAP size in MB for each container (default 512): " SWAP
    SWAP=${SWAP:-512}
    read -rp "Enter the number of cores for each container (default 2): " CORES
    CORES=${CORES:-2}
    read -rp "Enter the disk size for each container (default 25G): " DISK_SIZE
    DISK_SIZE=${DISK_SIZE:-25G}
    read -rp "Enter the storage pool (e.g., local-lvm): " STORAGE
    read -rp "Should the IP be set to DHCP? (yes/no): " DHCP_IP

    if [[ "$DHCP_IP" == "yes" ]]; then
        IP="dhcp"
    else
        # Ask if the IP should be auto-incremented
        read -rp "Should the IP address be auto-incremented? (yes/no): " AUTO_INCREMENT_IP
        if [[ "$AUTO_INCREMENT_IP" == "yes" ]]; then
            read -rp "Enter the initial IP address (e.g., 192.168.1.10/24): " INITIAL_IP
            IFS='/' read -r BASE_IP SUBNET <<< "$INITIAL_IP"
            IFS='.' read -r IP1 IP2 IP3 IP4 <<< "$BASE_IP"
        fi
    fi

    CONFIG_SUMMARY="Configuration Summary:\n"

    for ((i=0; i<NUM_CONTAINERS; i++)); do
        # Generate the CT ID, hostname, and IP address
        CTID=$((10000 + i))
        HOSTNAME="${PREFIX}$(printf "%02d" $CTID)${DOMAIN}"
        
        if [[ "$DHCP_IP" != "yes" && "$AUTO_INCREMENT_IP" == "yes" ]]; then
            IP="${IP1}.${IP2}.${IP3}.$((IP4 + i))/${SUBNET}"
        elif [[ "$DHCP_IP" != "yes" ]]; then
            read -rp "Enter the IP address for container $i (e.g., 192.168.1.10/24): " IP
        fi

        # Save the configuration
        save_configuration "$CTID $HOSTNAME $STORAGE $DISK_SIZE $MEMORY $SWAP $CORES $IP"

        # Append to the configuration summary
        CONFIG_SUMMARY+="\nCTID: $CTID\nHostname: $HOSTNAME\nIP: $IP\nMemory: $MEMORY MB\nSwap: $SWAP MB\nCores: $CORES\nDisk: $DISK_SIZE\nStorage: $STORAGE\n"

        # Create the container
        create_container $CTID $HOSTNAME $STORAGE $DISK_SIZE $MEMORY $SWAP $CORES $IP
    done

    echo -e "$CONFIG_SUMMARY"
    echo "All containers created successfully!"
}

# Run the main function
main
