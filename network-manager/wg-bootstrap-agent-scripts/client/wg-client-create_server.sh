#!/bin/bash

# Check if sufficient arguments are provided
if [ "$#" -ne 8 ]; then
    echo "Usage: $0 <WG_CLIENT_NAME> <WG_Client_Private_Key> <WG_Client_Public_Key> <SSH_Username> <Server_PublicKey> <Server_IP:Port> <Client_VPN_IP> <AllowedIPs>"
    exit 1
fi

# Script parameters
SERVER_NAME="wg0"
CLIENT_NAME="$1"
WG_CLIENT_PRIVATE_KEY="$2"
WG_CLIENT_PUBLIC_KEY="$3"
SSH_USERNAME="$4"
SERVER_PUBLIC_KEY="$5"
SERVER_IP_PORT="$6"
CLIENT_VPN_IP="$7"
ALLOWED_IPS="$8"
WG_DIR="/etc/wireguard/clients/$CLIENT_NAME"
CLIENT_CONF="$WG_DIR/${CLIENT_NAME}.conf"
SERVER_CONF="/etc/wireguard/${SERVER_NAME}.conf"

# Step 1: Install WireGuard (if not already installed)
if ! command -v wg > /dev/null; then
    sudo DEBIAN_FRONTEND=noninteractive apt install -y wireguard
fi

# Step 2: Create client directory
sudo mkdir -p "$WG_DIR"
mkdir -p /home/$SSH_USERNAME/wireguard/clients/$CLIENT_NAME

# Step 3: Generate Client Keys
sudo echo $WG_CLIENT_PRIVATE_KEY > "$WG_DIR/${CLIENT_NAME}_privatekey"
sudo echo $WG_CLIENT_PUBLIC_KEY > "$WG_DIR/${CLIENT_NAME}_publickey"
client_private_key=$(sudo cat "$WG_DIR/${CLIENT_NAME}_privatekey")
client_public_key=$(sudo cat "$WG_DIR/${CLIENT_NAME}_publickey")

# Step 4: Configure WireGuard Client
sudo bash -c "cat > $CLIENT_CONF <<EOF
[Interface]
PrivateKey = $client_private_key
Address = $CLIENT_VPN_IP
DNS = 1.1.1.1 # Change this if you have a preferred DNS server

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP_PORT
AllowedIPs = $ALLOWED_IPS
PersistentKeepalive = 25
EOF"

# Step 5: Update Server Configuration
sudo cp $CLIENT_CONF /home/$SSH_USERNAME/wireguard/clients/$CLIENT_NAME/$CLIENT_NAME.conf

sudo systemctl stop wg-quick@${SERVER_NAME}

sudo bash -c "echo -e '\n[Peer]\nPublicKey = $client_public_key\nAllowedIPs = $CLIENT_VPN_IP' >> $SERVER_CONF"

# Step 6: Restart WireGuard to apply changes
sudo systemctl restart wg-quick@${SERVER_NAME}

echo "Client configuration for $CLIENT_NAME created and added to server config."
echo "Transfer the client configuration to your client machine. Example command:"
echo "scp $CLIENT_CONF user@client-ip:/path/to/destination"
