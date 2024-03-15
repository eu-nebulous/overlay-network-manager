#!/bin/bash

# Check if sufficient arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <SSH_USERNAME> <WG_INTERFACE_NAME>"
    exit 1
fi

# Script parameter
SSH_USERNAME="$1"
WG_INTERFACE_NAME="$2"

# Step 1: Stop and Disable WireGuard Interface
sudo systemctl stop wg-quick@$WG_INTERFACE_NAME
sudo systemctl disable wg-quick@$WG_INTERFACE_NAME

# Step 2: Remove Wireguard packages
sudo apt-get remove --purge -y wireguard
sudo apt-get autoremove -y

echo "Wireguard packages have been removed."

# Step 3: Remove Wireguard related directories
sudo rm -rf /etc/wireguard
sudo rm -rf /home/$SSH_USERNAME/wireguard

echo "WireGuard configuration files removed."

# Step 4: Remove WG OpenSSL Private Key
sudo rm -rf /home/$SSH_USERNAME/wg-private-key.key

# Step 5: Remove OpenSSL Public Key
sed -i '/wireguard-pub/d' /home/$SSH_USERNAME/.ssh/authorized_keys

echo "WireGuard client $WG_INTERFACE_NAME has been stopped and disabled."
