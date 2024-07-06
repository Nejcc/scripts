#!/bin/bash

# Variables
BRIDGE="vmbr0"     # Network bridge to use
CONFIG_FILE="ct_config.txt"
PRESET_DIR="./presets"  # Directory to store preset configuration files

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
    local PASSWORD=$9

    echo "Creating container $CTID with hostname $HOSTNAME and IP $IP..."
    echo "Command: pct create $CTID local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst --hostname $HOSTNAME --storage $STORAGE --rootfs $STORAGE:$DISK_SIZE --memory $MEMORY --swap $SWAP --cores $CORES --net0 name=eth0,bridge=$BRIDGE,ip=$IP --password <hidden>"

    pct create $CTID local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst --hostname $HOSTNAME --storage $STORAGE --rootfs $STORAGE:$DISK_SIZE --memory $MEMORY --swap $SWAP --cores $CORES --net0 name=eth0,bridge=$BRIDGE,ip=$IP --password $PASSWORD

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
            return 0  # Existing configuration will be used
        else
            rm -f $CONFIG_FILE
            echo "Starting from scratch..."
        fi
    fi
    return 1  # New configuration will be created
}

# Function to check if a CT ID is available
is_ctid_available() {
    local CTID=$1
    if pct status $CTID &> /dev/null; then
        return 1  # CTID is in use
    else
        return 0  # CTID is available
    fi
}

# Function to find the next available CT ID
find_next_available_ctid() {
    local CTID=$1

    while ! is_ctid_available $CTID; do
        CTID=$((CTID + 1))
    done

    echo "$CTID"
}

# Function to check if an IP address is available
is_ip_available() {
    local IP=$1
    if ping -c 1 -W 1 ${IP%/*} &> /dev/null; then
        return 1  # IP is in use
    else
        return 0  # IP is available
    fi
}

# Function to find the next available IP address
find_next_available_ip() {
    local BASE_IP=$1
    local SUBNET=$2
    local IP1 IP2 IP3 IP4

    IFS='.' read -r IP1 IP2 IP3 IP4 <<< "$BASE_IP"
    
    while ! is_ip_available "${IP1}.${IP2}.${IP3}.${IP4}"; do
        IP4=$((IP4 + 1))
    done

    echo "${IP1}.${IP2}.${IP3}.${IP4}/${SUBNET}"
}

# Function to configure DNS
configure_dns() {
    local CTID=$1
    echo "Configuring DNS for container $CTID..."
    pct exec $CTID -- bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf && echo 'nameserver 8.8.4.4' >> /etc/resolv.conf"
}

# Function to update and upgrade the container
update_and_upgrade() {
    local CTID=$1
    echo "Updating and upgrading container $CTID..."
    pct exec $CTID -- bash -c "apt-get update && apt-get upgrade -y" || (configure_dns $CTID && pct exec $CTID -- bash -c "apt-get update && apt-get upgrade -y --fix-missing")
}

# Function to setup firewall
setup_firewall() {
    local CTID=$1
    echo "Setting up firewall for container $CTID..."
    pct exec $CTID -- bash -c "apt-get install -y ufw && ufw default deny incoming && ufw default allow outgoing && ufw allow ssh && ufw enable" || (configure_dns $CTID && pct exec $CTID -- bash -c "apt-get install -y ufw && ufw default deny incoming && ufw default allow outgoing && ufw allow ssh && ufw enable --fix-missing")
}

# Function to load preset configuration
load_preset_configuration() {
    local PRESET=$1
    local PRESET_FILE="$PRESET_DIR/$PRESET.txt"

    if [ -f $PRESET_FILE ]; then
        echo "Loading preset configuration from $PRESET_FILE..."
        source $PRESET_FILE
    else
        echo "Preset configuration file $PRESET_FILE not found. Using default values."
    fi
}

# Main function
main() {
    if ! load_configuration; then
        echo "Choose the type of container you want to set up:"
        echo "1. LB NS (Load balance for NS (pihole))"
        echo "2. NS (pihole) + ask for gravity-sync to be setup on servers (1,2,3,4 combinations)"
        echo "3. Grafana"
        echo "4. Prometheus"
        echo "5. Web server"
        echo "6. Clean setup"
        read -rp "Enter the number of your choice: " CHOICE

        case $CHOICE in
            1)
                PRESET="lb_ns"
                ;;
            2)
                PRESET="ns_pihole"
                ;;
            3)
                PRESET="grafana"
                ;;
            4)
                PRESET="prometheus"
                ;;
            5)
                PRESET="web_server"
                ;;
            6)
                PRESET="clean_setup"
                ;;
            *)
                echo "Invalid choice. Exiting."
                exit 1
                ;;
        esac

        load_preset_configuration $PRESET

        # Prompt for the common parameters with defaults
        read -rp "Enter the nameserver prefix (e.g., lb): " PREFIX
        read -rp "Enter the number of containers to create (default 1): " NUM_CONTAINERS
        NUM_CONTAINERS=${NUM_CONTAINERS:-1}
        read -rp "Enter the domain name (e.g., .local, default .local): " DOMAIN
        DOMAIN=${DOMAIN:-.local}
        read -rp "Enter the memory size in MB for each container (default $MEMORY): " MEMORY
        MEMORY=${MEMORY:-2048}
        read -rp "Enter the SWAP size in MB for each container (default $SWAP): " SWAP
        SWAP=${SWAP:-512}
        read -rp "Enter the number of cores for each container (default $CORES): " CORES
        CORES=${CORES:-2}
        read -rp "Enter the disk size for each container (default $DISK_SIZE): " DISK_SIZE
        DISK_SIZE=${DISK_SIZE:-25}
        read -rp "Enter the storage pool (e.g., local-lvm, default $STORAGE): " STORAGE
        STORAGE=${STORAGE:-local-lvm}
        read -rp "Should the IP be set to DHCP? (yes/no): " DHCP_IP
        read -rp "Enter the starting CT number (default 10000): " START_CID
        START_CID=${START_CID:-10000}
        read -rsp "Enter the password for the containers: " PASSWORD
        echo

        if [[ "$DHCP_IP" == "yes" ]]; then
            IP="dhcp"
        else
            # Ask if the IP should be auto-incremented
            read -rp "Should the IP address be auto-incremented? (yes/no): " AUTO_INCREMENT_IP
            if [[ "$AUTO_INCREMENT_IP" == "yes" ]]; then
                read -rp "Enter the initial IP address (e.g., 192.168.1.10/24): " INITIAL_IP
                IFS='/' read -r BASE_IP SUBNET <<< "$INITIAL_IP"
                IP=$(find_next_available_ip "$BASE_IP" "$SUBNET")
            else
                read -rp "Enter the IP address for container 0 (e.g., 192.168.1.10/24): " IP
                if ! is_ip_available "${IP%/*}"; then
                    echo "The IP address $IP is already in use. Please provide a different IP."
                    exit 1
                fi
            fi
        fi

        CONFIG_SUMMARY="Configuration Summary:\n"

        for ((i=0; i<NUM_CONTAINERS; i++)); do
            # Generate the CT ID, hostname, and IP address
            CTID=$((START_CID + i))
            if ! is_ctid_available $CTID; then
                read -rp "Container ID $CTID already exists. Do you want to find the next available CTID? (yes/no): " FIND_NEXT_CTID
                if [[ "$FIND_NEXT_CTID" == "yes" ]]; then
                    CTID=$(find_next_available_ctid $CTID)
                else
                    read -rp "Enter a new CTID: " CTID
                fi
            fi
            HOSTNAME="${PREFIX}$(printf "%02d" $((i+1)))${DOMAIN}"

            if [[ "$DHCP_IP" != "yes" && "$AUTO_INCREMENT_IP" == "yes" && "$i" -gt 0 ]]; then
                IFS='.' read -r IP1 IP2 IP3 IP4 <<< "${IP%/*}"
                IP4=$((IP4 + 1))
                IP="${IP1}.${IP2}.${IP3}.${IP4}/${SUBNET}"
                IP=$(find_next_available_ip "${IP%/*}" "$SUBNET")
            elif [[ "$DHCP_IP" != "yes" && "$i" -gt 0 ]]; then
                read -rp "Enter the IP address for container $i (e.g., 192.168.1.10/24): " IP
                if ! is_ip_available "${IP%/*}"; then
                    echo "The IP address $IP is already in use. Please provide a different IP."
                    exit 1
                fi
            fi

            # Save the configuration
            save_configuration "$CTID $HOSTNAME $STORAGE $DISK_SIZE $MEMORY $SWAP $CORES $IP $PASSWORD"

            # Append to the configuration summary
            CONFIG_SUMMARY+="\nCTID: $CTID\nHostname: $HOSTNAME\nIP: $IP\nMemory: $MEMORY MB\nSwap: $SWAP MB\nCores: $CORES\nDisk: $DISK_SIZE\nStorage: $STORAGE\n"

            # Create the container
            create_container $CTID $HOSTNAME $STORAGE $DISK_SIZE $MEMORY $SWAP $CORES $IP $PASSWORD
        done

        echo -e "$CONFIG_SUMMARY"
        echo "All containers created successfully!"
    fi

    # Prompt to start the created containers if using existing configuration
    read -rp "Do you want to start the created containers now? (yes/no): " START_CONTAINERS
    if [[ "$START_CONTAINERS" == "yes" ]]; then
        for ((i=0; i<NUM_CONTAINERS; i++)); do
            CTID=$((START_CID + i))
            echo "Starting container $CTID..."
            pct start $CTID
        done

        read -rp "Do you want to update and upgrade the containers? (yes/no): " UPDATE_CONTAINERS
        if [[ "$UPDATE_CONTAINERS" == "yes" ]]; then
            for ((i=0; i<NUM_CONTAINERS; i++)); do
                CTID=$((START_CID + i))
                update_and_upgrade $CTID
            done
        fi

        read -rp "Do you want to setup firewall on the containers? (yes/no): " SETUP_FIREWALL
        if [[ "$SETUP_FIREWALL" == "yes" ]]; then
            for ((i=0; i<NUM_CONTAINERS; i++)); do
                CTID=$((START_CID + i))
                setup_firewall $CTID
            done
        fi
    fi
}

# Run the main function
main
