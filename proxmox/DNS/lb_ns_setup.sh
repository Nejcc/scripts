#!/bin/bash

# Function to prompt for user input with default values
prompt_with_default() {
  local prompt=$1
  local default=$2
  read -p "$prompt [$default]: " input
  echo "${input:-$default}"
}

# Gather user input
num_lb=$(prompt_with_default "How many load balancers (LB) do you have" "2")
lb_ips=$(prompt_with_default "Provide IP list of load balancers (comma-separated)" "192.168.1.10,192.168.1.11")
num_ns=$(prompt_with_default "How many name servers (NS) do you have" "4")
ns_ips=$(prompt_with_default "Provide IP list of name servers (space-separated)" "192.168.1.20 192.168.1.21 192.168.1.22 192.168.1.23")

# Convert IP lists to arrays
IFS=',' read -r -a lb_ip_array <<< "$lb_ips"
IFS=' ' read -r -a ns_ip_array <<< "$ns_ips"

# Function to configure HAProxy on a load balancer
configure_haproxy() {
  local ctid=$1
  local ns_ips=("${@:2}")
  local backend_config="backend dns_backend\n    mode tcp\n    balance roundrobin\n"
  for ns_ip in "${ns_ips[@]}"; do
    backend_config+="    server ns${ns_ip##*.} $ns_ip:53 check\n"
  done

  local config="
frontend dns_frontend
    bind *:53
    mode tcp
    default_backend dns_backend

$backend_config
"
  echo -e "$config" > /tmp/haproxy.cfg
  pct push $ctid /tmp/haproxy.cfg /etc/haproxy/haproxy.cfg
  pct exec $ctid -- systemctl restart haproxy
}

# Function to install and configure HAProxy on load balancers
setup_load_balancers() {
  echo "Setting up Load Balancers..."
  for i in "${!lb_ip_array[@]}"; do
    local ctid=$((10000 + i))
    echo "Configuring Load Balancer ${lb_ip_array[$i]} with CTID $ctid"

    pct set $ctid --hostname "lb0$(($i + 1)).local"
    pct set $ctid --net0 name=eth0,bridge=vmbr0,ip=${lb_ip_array[$i]}/24
    pct set $ctid --memory 2048 --swap 512 --cores 2
    pct set $ctid --rootfs local-lvm:25G
    
    # Install and configure HAProxy
    pct exec $ctid -- apt-get update
    pct exec $ctid -- apt-get install -y haproxy
    configure_haproxy $ctid "${ns_ip_array[@]}"
    
    echo "Load Balancer ${lb_ip_array[$i]} configured with HAProxy"
  done
}

# Function to install Pi-hole and GravitySync on name servers
setup_name_servers() {
  echo "Setting up Name Servers..."
  for i in "${!ns_ip_array[@]}"; do
    local ctid=$((10010 + i))
    echo "Configuring Name Server ${ns_ip_array[$i]} with CTID $ctid"

    pct set $ctid --hostname "ns0$(($i + 1)).local"
    pct set $ctid --net0 name=eth0,bridge=vmbr0,ip=${ns_ip_array[$i]}/24
    pct set $ctid --memory 2048 --swap 512 --cores 2
    pct set $ctid --rootfs local-lvm:25G
    
    # Install Pi-hole and GravitySync
    pct exec $ctid -- bash -c "$(curl -sSL https://install.pi-hole.net)"
    pct exec $ctid -- bash -c "curl -sSL https://gravitysync.com/install.sh | bash"
    
    # Configure firewall to allow communication with load balancers
    pct exec $ctid -- apt-get update
    pct exec $ctid -- apt-get install -y ufw
    pct exec $ctid -- ufw allow 22/tcp
    pct exec $ctid -- ufw allow 53/tcp
    for lb_ip in "${lb_ip_array[@]}"; do
      pct exec $ctid -- ufw allow from $lb_ip
    done
    pct exec $ctid -- ufw enable
    
    echo "Name Server ${ns_ip_array[$i]} configured with Pi-hole, GravitySync, and firewall rules"
  done
}

# Run setup functions
setup_load_balancers
setup_name_servers
