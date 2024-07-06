#!/bin/bash

# Function to configure network interfaces for a VM
configure_network() {
    local vmid=$1
    local bridge=$2
    qm set $vmid -net0 model=virtio,bridge=$bridge
}

# Function to install HAProxy on a VM
install_haproxy() {
    local vmid=$1
    qm guest exec $vmid -- apt update
    qm guest exec $vmid -- apt install -y haproxy
}

# Function to configure HAProxy on a VM
configure_haproxy() {
    local vmid=$1
    local haproxy_cfg="/etc/haproxy/haproxy.cfg"
    
    cat <<EOF | qm guest exec $vmid -- bash -c "cat > $haproxy_cfg"
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log global
    mode http
    option httplog
    option dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend pihole_frontend
    bind *:80
    mode http
    default_backend pihole_backend

backend pihole_backend
    mode http
    balance roundrobin
EOF

    for i in "${!ns_vms[@]}"; do
        cat <<EOF | qm guest exec $vmid -- bash -c "cat >> $haproxy_cfg"
    server ns0$i ${ns_vms[$i]}:80 check
EOF
    done

    cat <<EOF | qm guest exec $vmid -- bash -c "cat >> $haproxy_cfg"

listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
EOF

    qm guest exec $vmid -- systemctl restart haproxy
}

# Main script
read -p "Enter the bridge name (e.g., vmbr0): " bridge

read -p "Enter the IDs of the load balancer VMs (comma-separated): " lb_input
IFS=',' read -r -a lb_vms <<< "$lb_input"

read -p "Enter the IPs of the name server VMs (comma-separated): " ns_input
IFS=',' read -r -a ns_vms <<< "$ns_input"

# Configure network interfaces for LB and NS VMs
for vmid in "${lb_vms[@]}"; do
    configure_network $vmid $bridge
    install_haproxy $vmid
    configure_haproxy $vmid
done

for vmid in "${ns_vms[@]}"; do
    configure_network $vmid $bridge
done

echo "Setup complete. Load balancers and name servers are configured."
