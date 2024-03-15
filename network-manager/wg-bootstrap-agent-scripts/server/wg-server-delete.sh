#!/bin/bash

# Script parameter: WireGuard interface name (e.g., wg0)
WG_INTERFACE=wg0

# Script parameter
SSH_USERNAME="$1"

# Step 1: Disable and stop the WireGuard service
sudo systemctl stop wg-quick@$WG_INTERFACE
sudo systemctl disable wg-quick@$WG_INTERFACE

# Step 2: Remove the WireGuard interface
sudo ip link delete $WG_INTERFACE

# Step 3: Remove Wiregaurd packages
sudo apt remove --purge -y wireguard
sudo apt autoremove -y

# Step 4: Remove OpenSSL Public Key
sed -i '/wireguard-pub/d' /home/$SSH_USERNAME/.ssh/authorized_keys

# Step 5: Remove Wireguard related directories
sudo rm -rf /etc/wireguard
sudo rm -rf /home/$SSH_USERNAME/wireguard

echo "WireGuard has been uninstalled."
echo "WireGuard server $WG_INTERFACE has been removed."
