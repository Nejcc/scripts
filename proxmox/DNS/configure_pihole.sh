#!/bin/bash

# Check if CTID is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <CTID>"
  exit 1
fi

CTID=$1

# Modify the LXC configuration
echo "Modifying LXC configuration for CTID $CTID..."
cat <<EOL >> /etc/pve/lxc/$CTID.conf
lxc.apparmor.profile: unconfined
lxc.cap.drop:
lxc.cgroup.devices.allow: a
lxc.mount.auto: proc:rw sys:rw
lxc.seccomp.profile:
EOL

# Restart the container to apply new configuration
echo "Restarting the container $CTID..."
pct stop $CTID
pct start $CTID

# Execute commands inside the container
echo "Executing commands inside the container..."

pct exec $CTID -- bash -c "
apt update && apt upgrade -y
systemctl status lighttpd
systemctl status pihole-FTL
apt-get update --fix-missing
apt-get install curl dnsutils iptables ufw -y
apt-get update --fix-missing
apt update && apt upgrade -y
apt install lighttpd -y
systemctl status pihole-FTL
journalctl -xeu pihole-FTL.service
systemctl status lighttpd
ufw status
ufw allow http
ufw reload
pihole -a -p
"

echo "Configuration and troubleshooting steps completed for CTID $CTID."
