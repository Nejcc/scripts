#!/bin/bash

# Function to configure network interfaces for a container
configure_network() {
    local ctid=$1
    local bridge=$2
    pct set $ctid -net0 name=eth0,bridge=$bridge,ip=dhcp
}

# Function to install HAProxy on a container
install_haproxy() {
    local ctid=$1
    pct exec $ctid -- apt update
    pct exec $ctid -- apt install -y haproxy
}

# Function to configure HAProxy on a container
configure_haproxy() {
    local ctid=$1
    local haproxy_cfg="/etc/haproxy/haproxy.cfg"

    pct exec $ctid -- bash -c "cat > $haproxy_cfg" <<EOF
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

    for i in "${!ns_ips[@]}"; do
        pct exec $ctid -- bash -c "echo '    server ns0$i ${ns_ips[$i]}:80 check' >> $haproxy_cfg"
    done

    pct exec $ctid -- bash -c "cat >> $haproxy_cfg" <<EOF

listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
EOF

    pct exec $ctid -- systemctl restart haproxy
}

# Main script
read -p "Enter the bridge name (e.g., vmbr0): " bridge

read -p "Enter the CTIDs of the load balancer containers (comma-separated): " lb_input
IFS=',' read -r -a lb_ctids <<< "$lb_input"

read -p "Enter the IPs of the name server containers (comma-separated): " ns_input
IFS=',' read -r -a ns_ips <<< "$ns_input"

# Configure network interfaces for LB and NS containers
for ctid in "${lb_ctids[@]}"; do
    configure_network $ctid $bridge
    install_haproxy $ctid
    configure_haproxy $ctid
done

for ctid in "${ns_ips[@]}"; do
    configure_network $ctid $bridge
done

echo "Setup complete. Load balancers and name servers are configured."
