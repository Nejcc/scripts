#!/bin/bash

# Array of CTIDs for Name Servers
ns_ctids=(10010 10011 10012 10013)
ns_hostnames=("ns001.local" "ns002.local" "ns003.local" "ns004.local")
ns_ips=("192.168.1.20/24" "192.168.1.21/24" "192.168.1.22/24" "192.168.1.23/24")
memory=2048
swap=512
cores=2
disk=25
storage="local-lvm"

install_pihole() {
  local ctid=$1
  echo "Installing Pi-hole on CTID $ctid"
  pct exec $ctid -- bash -c "$(curl -sSL https://install.pi-hole.net)"
}

install_gravitysync() {
  local ctid=$1
  echo "Installing GravitySync on CTID $ctid"
  pct exec $ctid -- bash -c "curl -sSL https://gravitysync.com/install.sh | bash"
}

for i in "${!ns_ctids[@]}"; do
  echo "Configuring Name Server ${ns_hostnames[$i]} with CTID ${ns_ctids[$i]}"

  pct set ${ns_ctids[$i]} --hostname ${ns_hostnames[$i]}
  pct set ${ns_ctids[$i]} --net0 name=eth0,bridge=vmbr0,ip=${ns_ips[$i]}
  pct set ${ns_ctids[$i]} --memory $memory --swap $swap --cores $cores
  pct set ${ns_ctids[$i]} --rootfs $storage:$disk
  
  # Install Pi-hole and GravitySync
  install_pihole ${ns_ctids[$i]}
  install_gravitysync ${ns_ctids[$i]}
  
  echo "Name Server ${ns_hostnames[$i]} configured and Pi-hole with GravitySync installed"
done
