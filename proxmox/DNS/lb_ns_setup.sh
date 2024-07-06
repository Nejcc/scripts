#!/bin/bash

# Array of CTIDs for Load Balancers
lb_ctids=(10000 10001)
lb_hostnames=("lb01.local" "lb02.local")
lb_ips=("192.168.1.10/24" "192.168.1.11/24")
memory=2048
swap=512
cores=2
disk=25
storage="local-lvm"

for i in "${!lb_ctids[@]}"; do
  echo "Configuring Load Balancer ${lb_hostnames[$i]} with CTID ${lb_ctids[$i]}"

  pct set ${lb_ctids[$i]} --hostname ${lb_hostnames[$i]}
  pct set ${lb_ctids[$i]} --net0 name=eth0,bridge=vmbr0,ip=${lb_ips[$i]}
  pct set ${lb_ctids[$i]} --memory $memory --swap $swap --cores $cores
  pct set ${lb_ctids[$i]} --rootfs $storage:$disk
  
  echo "Load Balancer ${lb_hostnames[$i]} configured"
done
