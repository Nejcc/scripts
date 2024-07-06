#!/bin/bash

# Function to prompt for user input with default values
prompt_with_default() {
  local prompt=$1
  local default=$2
  read -p "$prompt [$default]: " input
  echo "${input:-$default}"
}

# Function to prompt for yes/no input
prompt_yes_no() {
  local prompt=$1
  while true; do
    read -p "$prompt [y/n]: " input
    case $input in
      [Yy]* ) echo "yes"; return;;
      [Nn]* ) echo "no"; return;;
      * ) echo "Please answer yes or no.";;
    esac
  done
}

# Gather user input
num_lb=$(prompt_with_default "How many load balancers (LB) do you have" "2")
lb_ips=$(prompt_with_default "Provide IP list of load balancers (comma-separated)" "192.168.1.10,192.168.1.11")
num_ns=$(prompt_with_default "How many name servers (NS) do you have" "4")
ns_ips=$(prompt_with_default "Provide IP list of name servers (space-separated)" "192.168.1.20 192.168.1.21 192.168.1.22 192.168.1.23")
fresh_install=$(prompt_yes_no "Do you want to perform a fresh install of HAProxy, Pi-hole, and GravitySync?")

# Convert IP lists to arrays
IFS=',' read -r -a lb_ip_array <<< "$lb_ips"
IFS=' ' read -r -a ns_ip_array <<< "$ns_ips"

# Function to configure DNS inside containers
configure_dns() {
  local ctid=$1
  pct exec $ctid -- bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
  pct exec $ctid -- bash -c "echo 'nameserver 8.8.4.4' >> /etc/resolv.conf"
  # Verify DNS resolution
  pct exec $ctid -- ping -c 1 deb.debian.org
}

# Function to start a container if not running
start_container_if_not_running() {
  local ctid=$1
  if ! pct status $ctid | grep -q 'status: running'; then
    echo "Starting container $ctid..."
    pct start $ctid
    sleep 5 # Wait for the container to fully start
  fi
}

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

# Function to install HAProxy on load balancers
setup_load_balancers() {
  echo "Setting up Load Balancers..."
  for i in "${!lb_ip_array[@]}"; do
    local ctid=$((10000 + i))
    echo "Configuring Load Balancer ${lb_ip_array[$i]} with CTID $ctid"

    pct set $ctid --tag "under-maintenance"
    
    # Start the container if not running
    start_container_if_not_running $ctid
    
    # Ensure DNS is configured
    configure_dns $ctid

    # Install and configure HAProxy
    if [ "$fresh_install" == "yes" ]; then
      pct exec $ctid -- apt-get update || true
      pct exec $ctid -- apt-get install -y haproxy || true
    fi
    configure_haproxy $ctid "${ns_ip_array[@]}"
    
    # Update tag to "LBNS"
    pct set $ctid --tag "LBNS"
    echo "Load Balancer ${lb_ip_array[$i]} configured with HAProxy"
  done
}

# Function to install Pi-hole and GravitySync on name servers
setup_name_servers() {
  echo "Setting up Name Servers..."
  for i in "${!ns_ip_array[@]}"; do
    local ctid=$((10010 + i))
    echo "Configuring Name Server ${ns_ip_array[$i]} with CTID $ctid"
    pct set $ctid --tag "under-maintenance"

    # Start the container if not running
    start_container_if_not_running $ctid

    # Ensure DNS is configured
    configure_dns $ctid

    # Install Pi-hole and GravitySync
    if [ "$fresh_install" == "yes" ]; then
      pct exec $ctid -- apt-get update || true
      pct exec $ctid -- apt-get install -y curl || true
      pct exec $ctid -- bash -c "$(curl -sSL https://install.pi-hole.net)" || true
      pct exec $ctid -- bash -c "curl -sSL https://gravitysync.com/install.sh | bash" || true
    fi
    
    # Configure firewall to allow communication with load balancers
    pct exec $ctid -- apt-get install -y ufw || true
    pct exec $ctid -- ufw allow 22/tcp || true
    pct exec $ctid -- ufw allow 53/tcp || true
    for lb_ip in "${lb_ip_array[@]}"; do
      pct exec $ctid -- ufw allow from $lb_ip || true
    done
    pct exec $ctid -- ufw enable || true
    
    # Update tag to "NS"
    pct set $ctid --tag "NS"
    echo "Name Server ${ns_ip_array[$i]} configured with Pi-hole, GravitySync, and firewall rules"
  done
}

# Run setup functions
setup_load_balancers
setup_name_servers
