#!/bin/bash

# Check if sufficient arguments are provided
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <WORKER_SSH_USERNAME> <OPENSSL_PRIVATE_KEY> <SERVER_IP> <CLIENT_NAME> <MASTER_SSH_USERNAME>"
    exit 1
fi

# Script parameter
WORKER_SSH_USERNAME="$1"
OPENSSL_PRIVATE_KEY="$2"
SERVER_IP="$3"
CLIENT_NAME="$4"
MASTER_SSH_USERNAME="$5"

# Update Package Repository. Upgrade and Autoremove Packages
sudo DEBIAN_FRONTEND=noninteractive apt-get -y update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get -y autoremove


# Step 1: Install WireGuard
if ! command -v wg > /dev/null; then
    sudo DEBIAN_FRONTEND=noninteractive apt install -y wireguard
    sudo DEBIAN_FRONTEND=noninteractive apt install -y resolvconf
fi

# Step 2: Base64 Decode the OpenSSH Private Key file
echo $OPENSSL_PRIVATE_KEY | base64 -d --ignore-garbage > /home/$WORKER_SSH_USERNAME/wg-private-key.key
chmod 400 /home/$WORKER_SSH_USERNAME/wg-private-key.key

# Step 3: Secure Copy to WG Server to get your conf file
scp -o StrictHostKeyChecking=no -i /home/$WORKER_SSH_USERNAME/wg-private-key.key $MASTER_SSH_USERNAME@$SERVER_IP:/home/$MASTER_SSH_USERNAME/wireguard/clients/$CLIENT_NAME/$CLIENT_NAME.conf /home/$WORKER_SSH_USERNAME/wireguard
sudo cp /home/$WORKER_SSH_USERNAME/wireguard/$CLIENT_NAME.conf /etc/wireguard/$CLIENT_NAME.conf

# Step 4: Enable and Start WireGuard Client Interface
sudo systemctl enable wg-quick@$CLIENT_NAME
sudo systemctl start wg-quick@$CLIENT_NAME

echo "WireGuard client configured and started for $CLIENT_NAME"
