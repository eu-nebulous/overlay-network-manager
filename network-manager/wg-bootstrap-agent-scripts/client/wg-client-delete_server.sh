#!/bin/bash

# Check if the client public key is provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <Client_Name> <Client_PublicKey> <SSH_Username>"
    exit 1
fi

# Script parameter
SERVER_NAME="wg0"
CLIENT_NAME="$1"
CLIENT_PUBLIC_KEY="$2"
SSH_USERNAME="$3"

# Step 1: Remove the client configuration from the server
sudo wg set ${SERVER_NAME} peer ${CLIENT_PUBLIC_KEY} remove

# Step 2: Remove the client config file
sudo rm -rf /etc/wireguard/clients/${CLIENT_NAME}
sudo rm -rf /home/$SSH_USERNAME/wireguard/clients/${CLIENT_NAME}

# Step 3: Restart WireGuard to apply changes
sudo systemctl restart wg-quick@${SERVER_NAME}

echo "Client with public key $CLIENT_PUBLIC_KEY has been removed from the server configuration."
