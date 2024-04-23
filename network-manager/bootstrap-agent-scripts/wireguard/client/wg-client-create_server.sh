#!/bin/bash

# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
LOGFILE="/var/log/wg-client-create_server.$PID.log"

# Set up the logging for the script
sudo touch $LOGFILE
sudo chown $USER:$USER $LOGFILE

# All the output of this shell script is redirected to the LOGFILE
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>$LOGFILE 2>&1

# A function to print a message to the stdout as well as as the LOGFILE
log_print(){
  level=$1
  Message=$2
  echo "$level [$(date)]: $Message"
  echo "$level [$(date)]: $Message" >&3
}

# Check if sufficient arguments are provided
if [ "$#" -ne 8 ]; then
    log_print WARN "Usage: $0 <WG_CLIENT_NAME> <WG_Client_Private_Key> <WG_Client_Public_Key> <SSH_Username> <Server_PublicKey> <Server_IP:Port> <Client_VPN_IP> <AllowedIPs>"
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

log_print INFO "Script Parameters: SERVER_NAME=$SERVER_NAME, CLIENT_NAME=$CLIENT_NAME, WG_CLIENT_PRIVATE_KEY=$WG_CLIENT_PRIVATE_KEY
                WG_CLIENT_PUBLIC_KEY=$WG_CLIENT_PUBLIC_KEY, SSH_USERNAME=$SSH_USERNAME,
                SERVER_PUBLIC_KEY=$SERVER_PUBLIC_KEY, SERVER_IP_PORT=$SERVER_IP_PORT, CLIENT_VPN_IP=$CLIENT_VPN_IP,
                ALLOWED_IPS=$ALLOWED_IPS, WG_DIR=$WG_DIR, CLIENT_CONF=$CLIENT_CONF, SERVER_CONF=$SERVER_CONF"

# Step 1: Create client directory
sudo mkdir -p "$WG_DIR"
mkdir -p /home/$SSH_USERNAME/wireguard/clients/$CLIENT_NAME

log_print INFO "Generate Client Keys"
# Step 2: Generate Client Keys
sudo echo $WG_CLIENT_PRIVATE_KEY > "$WG_DIR/${CLIENT_NAME}_privatekey"
sudo echo $WG_CLIENT_PUBLIC_KEY > "$WG_DIR/${CLIENT_NAME}_publickey"
client_private_key=$(sudo cat "$WG_DIR/${CLIENT_NAME}_privatekey")
client_public_key=$(sudo cat "$WG_DIR/${CLIENT_NAME}_publickey")

log_print INFO "Configure WireGuard Client"
# Step 3: Configure WireGuard Client
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

log_print INFO "Update Server Configuration"
# Step 4: Update Server Configuration
sudo cp $CLIENT_CONF /home/$SSH_USERNAME/wireguard/clients/$CLIENT_NAME/$CLIENT_NAME.conf

sudo systemctl stop wg-quick@${SERVER_NAME}

sudo bash -c "echo -e '\n[Peer]\nPublicKey = $client_public_key\nAllowedIPs = $CLIENT_VPN_IP' >> $SERVER_CONF"

log_print INFO "Restart WireGuard to apply changes"
# Step 5: Restart WireGuard to apply changes
sudo systemctl restart wg-quick@${SERVER_NAME}

log_print INFO "Client configuration for $CLIENT_NAME created and added to server config."

# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "wg-client-create_server.sh: Configuration done successfully in $ELAPSED seconds "