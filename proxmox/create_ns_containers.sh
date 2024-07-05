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
    local TEMPLATE_ID=${10}
    local STORAGE=${11}

    echo "Creating container $CTID with hostname $HOSTNAME and IP $IP using template $TEMPLATE_ID..."
    echo "Command: pct create $CTID $TEMPLATE_ID --hostname $HOSTNAME --cores $CORES --memory $RAM --swap $SWAP --net0 name=eth0,bridge=$BRIDGE,ip=$IP --rootfs $STORAGE:$DISK_SIZE --password <hidden> --onboot $START_AT_BOOT --start 1"

    pct create $CTID $TEMPLATE_ID --hostname $HOSTNAME --cores $CORES --memory $RAM --swap $SWAP \
        --net0 name=eth0,bridge=$BRIDGE,ip=$IP --rootfs $STORAGE:$DISK_SIZE \
        --password $PASSWORD --onboot $START_AT_BOOT --start 1

    if [ $? -eq 0 ]; then
        echo "Container $CTID created successfully!"
    else
        echo "Failed to create container $CTID. Please check the Proxmox logs for more details."
        exit 1
    fi
}

# Main function
main() {
    load_configuration

    # Prompt for the common parameters
    read -rp "Enter the nameserver prefix (e.g., lb): " PREFIX
    read -rp "Enter the number of containers to create: " NUM_CONTAINERS
    read -rp "Enter the domain name (e.g., .local): " DOMAIN
    read -rp "Enter the number of cores for each container: " CORES
    read -rp "Enter the RAM size in MB for each container: " RAM
    read -rp "Enter the SWAP size in MB for each container: " SWAP
    read -rp "Enter the disk size for each container (e.g., 10G): " DISK_SIZE
    read -rp "Enter the storage pool (e.g., local-lvm): " STORAGE
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

    for ((i=1; i<=NUM_CONTAINERS; i++)); do
        # Generate the CT ID, hostname, and IP address
        CTID=$((100 + i))
        HOSTNAME="${PREFIX}$(printf "%02d" $i)${DOMAIN}"
        
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
        save_configuration "$CTID $HOSTNAME $IP $PASSWORD $CORES $RAM $SWAP $DISK_SIZE $START_AT_BOOT $TEMPLATE_ID $STORAGE"

        # Append to the configuration summary
        CONFIG_SUMMARY+="CTID: $CTID, Hostname: $HOSTNAME, IP: $IP, Cores: $CORES, RAM: $RAM MB, SWAP: $SWAP MB, Disk: $DISK_SIZE, Storage: $STORAGE, Start at boot: $START_AT_BOOT, Template ID: $TEMPLATE_ID\n"

        # Create the container
        create_container $CTID $HOSTNAME $IP $PASSWORD $CORES $RAM $SWAP $DISK_SIZE $START_AT_BOOT $TEMPLATE_ID $STORAGE

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
