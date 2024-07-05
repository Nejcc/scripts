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
    local CORES=$5
    local RAM=$6
    local SWAP=$7
    local DISK_SIZE=$8
    local START_AT_BOOT=$9
    local TEMPLATE=${10}
    local STORAGE=${11}

    echo "Creating container $CTID with hostname $HOSTNAME and IP $IP using template $TEMPLATE..."
    echo "Command: pct create $CTID local:vztmpl/$TEMPLATE --hostname $HOSTNAME --cores $CORES --memory $RAM --swap $SWAP --net0 name=eth0,bridge=$BRIDGE,ip=$IP --rootfs $STORAGE:$DISK_SIZE --password <hidden> --onboot $START_AT_BOOT --start 1"

    pct create $CTID local:vztmpl/$TEMPLATE --hostname $HOSTNAME --cores $CORES --memory $RAM --swap $SWAP \
        --net0 name=eth0,bridge=$BRIDGE,ip=$IP --rootfs $STORAGE:$DISK_SIZE \
        --password $PASSWORD --onboot $START_AT_BOOT --start 1

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

# Function to select a template from available options
select_template() {
    local TEMPLATES=("debian-11-standard_11.7-1_amd64.tar.zst"
                     "debian-11-turnkey-mattermost_17.2-1_amd64.tar.gz"
                     "debian-11-turnkey-nextcloud_17.2-1_amd64.tar.gz"
                     "debian-12-standard_12.0-1_amd64.tar.zst"
                     "ubuntu-22.04-standard_22.04-1_amd64.tar.zst")
    
    echo "Available templates:"
    for i in "${!TEMPLATES[@]}"; do
        echo "$((i+1))) ${TEMPLATES[i]}"
    done

    read -rp "Select a template by number: " TEMPLATE_INDEX
    TEMPLATE=${TEMPLATES[$((TEMPLATE_INDEX-1))]}
    echo "Selected template: $TEMPLATE"
}

# Main function
main() {
    load_configuration

    # Prompt for the common parameters
    read -rp "Enter the nameserver prefix (e.g., lb): " PREFIX
    read -rp "Enter the number of containers to create: " NUM_CONTAINERS
    read -rp "Enter the domain name (e.g., .local): " DOMAIN
    read -rp "Enter the number of cores for each container (default 2): " CORES
    CORES=${CORES:-2}
    read -rp "Enter the RAM size in MB for each container (default 2048): " RAM
    RAM=${RAM:-2048}
    read -rp "Enter the SWAP size in MB for each container (default 512): " SWAP
    SWAP=${SWAP:-512}
    read -rp "Enter the disk size for each container (default 20G): " DISK_SIZE
    DISK_SIZE=${DISK_SIZE:-20G}
    read -rp "Enter the storage pool (e.g., local-lvm): " STORAGE
    select_template
    read -rp "Should the containers start at boot? (yes/no): " START_AT_BOOT
    read -rp "Enter the initial template ID: " INITIAL_TEMPLATE_ID

    # Ask if the template ID should be auto-incremented
    read -rp "Should the template ID be auto-incremented? (yes/no): " AUTO_INCREMENT_TEMPLATE_ID

    # Ask if the password should be the same for each machine
    read -rp "Should the password be the same for each container? (yes/no): " SAME_PASSWORD
    if [[ "$SAME_PASSWORD" == "yes" ]]; then
        read -rsp "Enter the password for all containers: " PASSWORD
        echo
    fi

    # Ask if the IP should be auto-incremented
    read -rp "Should the IP address be auto-incremented? (yes/no): " AUTO_INCREMENT_IP
    if [[ "$AUTO_INCREMENT_IP" == "yes" ]]; then
        read -rp "Enter the initial IP address (e.g., 192.168.1.10/24): " INITIAL_IP
        IFS='/' read -r BASE_IP SUBNET <<< "$INITIAL_IP"
        IFS='.' read -r IP1 IP2 IP3 IP4 <<< "$BASE_IP"
    fi

    # Convert the yes/no input to a numeric value
    if [[ "$START_AT_BOOT" == "yes" ]]; then
        START_AT_BOOT=1
    else
        START_AT_BOOT=0
    fi

    TEMPLATE_ID=$INITIAL_TEMPLATE_ID

    CONFIG_SUMMARY="Configuration Summary:\n"

    for ((i=0; i<NUM_CONTAINERS; i++)); do
        # Generate the CT ID, hostname, and IP address
        CTID=$((100 + i))
        HOSTNAME="${PREFIX}$(printf "%02d" $CTID)${DOMAIN}"
        
        if [[ "$AUTO_INCREMENT_IP" == "yes" ]]; then
            IP="${IP1}.${IP2}.${IP3}.$((IP4 + i))/${SUBNET}"
        else
            read -rp "Enter the IP address for container $i (e.g., 192.168.1.10/24): " IP
        fi
        
        if [[ "$SAME_PASSWORD" != "yes" ]]; then
            read -rsp "Enter the password for container $i: " PASSWORD
            echo
        fi

        # Save the configuration
        save_configuration "$CTID $HOSTNAME $IP $PASSWORD $CORES $RAM $SWAP $DISK_SIZE $START_AT_BOOT $TEMPLATE_ID $STORAGE $TEMPLATE"

        # Append to the configuration summary
        CONFIG_SUMMARY+="\nCTID: $CTID\nHostname: $HOSTNAME\nIP: $IP\nCores: $CORES\nRAM: $RAM MB\nSWAP: $SWAP MB\nDisk: $DISK_SIZE\nStorage: $STORAGE\nStart at boot: $START_AT_BOOT\nTemplate ID: $TEMPLATE_ID\nTemplate: $TEMPLATE\n"

        # Create the container
        create_container $CTID $HOSTNAME $IP $PASSWORD $CORES $RAM $SWAP $DISK_SIZE $START_AT_BOOT $TEMPLATE $STORAGE

        # Auto-increment the template ID if needed
        if [[ "$AUTO_INCREMENT_TEMPLATE_ID" == "yes" ]]; then
            TEMPLATE_ID=$((TEMPLATE_ID + 1))
        else
            # Prompt for the next template ID if not auto-incrementing
            read -rp "Enter the template ID for the next container: " TEMPLATE_ID
        fi
    done

    echo -e "$CONFIG_SUMMARY"
    echo "All containers created successfully!"
}

# Run the main function
main
