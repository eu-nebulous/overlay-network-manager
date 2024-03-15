#!/bin/bash

# Check if sufficient arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <WG_Server_Private_Key> <WG_Server_Public_Key> <WG_Server_IP>"
    exit 1
fi

# Script parameters
WG_SERVER_PRIVATE_KEY="$1"
WG_SERVER_PUBLIC_KEY="$2"
WG_INTERFACE="wg0"
SERVER_IP="$3"
LISTEN_PORT="51820"
WG_DIR="/etc/wireguard"
SERVER_KEYS_DIR="$WG_DIR/server_keys"
SERVER_CONF="$WG_DIR/$WG_INTERFACE.conf"

# Update Package Repository. Upgrade and Autoremove Packages
sudo DEBIAN_FRONTEND=noninteractive apt-get -y update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get -y autoremove

# Step 1: Install WireGuard package
if ! command -v wg > /dev/null; then
	sudo DEBIAN_FRONTEND=noninteractive apt install -y wireguard
  sudo DEBIAN_FRONTEND=noninteractive apt install -y resolvconf
fi

# Step 2: Create directories for keys and configuration
sudo mkdir -p "$SERVER_KEYS_DIR"
sudo mkdir -p "$WG_DIR"

# Step 3: Generate Server Keys
sudo echo $WG_SERVER_PRIVATE_KEY > "$SERVER_KEYS_DIR/${WG_INTERFACE}_privatekey"
sudo echo $WG_SERVER_PUBLIC_KEY > "$SERVER_KEYS_DIR/${WG_INTERFACE}_publickey"
server_private_key=$(sudo cat "$SERVER_KEYS_DIR/${WG_INTERFACE}_privatekey")

# Step 4: Create Server Configuration File
sudo bash -c "cat > $SERVER_CONF <<EOF
[Interface]
Address = $SERVER_IP
ListenPort = $LISTEN_PORT
PrivateKey = $server_private_key
SaveConfig = true
EOF"

# Step 5: Enable and Start WireGuard
sudo systemctl enable wg-quick@$WG_INTERFACE
sudo systemctl start wg-quick@$WG_INTERFACE

echo "WireGuard server is up and running!"
echo "Server configuration is located at $SERVER_CONF"
echo "Server keys are stored in $SERVER_KEYS_DIR"
