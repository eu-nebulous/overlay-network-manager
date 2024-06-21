#!/bin/bash

# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
LOGFILE="/var/log/wg-register-node.$PID.log"

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
if [ "$#" -ne 3 ]; then
    log_print WARN "Usage: $0 <WG_Node_Private_Key> <WG_Node_Public_Key> <WG_Node_IP>"
    exit 1
fi

# Script parameters
WG_NODE_PRIVATE_KEY="$1"
WG_NODE_PUBLIC_KEY="$2"
WG_NODE_IP="$3"
WG_NODE_INTERFACE="wg$WG_NODE_IP"
WG_NODE_LISTEN_PORT="51820"
WG_NODE_DIR="/etc/wireguard"
WG_NODE_KEYS_DIR="$WG_NODE_DIR/node_keys"
WG_NODE_CONF="$WG_NODE_DIR/$WG_NODE_INTERFACE.conf"

log_print INFO "Script Parameters: WG_NODE_PRIVATE_KEY=$WG_NODE_PRIVATE_KEY, WG_NODE_PUBLIC_KEY=$WG_NODE_PUBLIC_KEY,
                WG_NODE_INTERFACE=$WG_NODE_INTERFACE, WG_NODE_IP=$WG_NODE_IP,
                WG_NODE_LISTEN_PORT=$WG_NODE_LISTEN_PORT, WG_NODE_DIR=$WG_NODE_DIR, WG_NODE_KEYS_DIR=$WG_NODE_KEYS_DIR,
                WG_NODE_CONF=$WG_NODE_CONF"

# Step 1: Create directories for keys and configuration
log_print INFO "Create directories for keys and configuration"
sudo mkdir -p "$WG_NODE_KEYS_DIR"
sudo mkdir -p "$WG_NODE_DIR"

# Step 2: Store Wireguard Keys
log_print INFO "Store Wireguard Keys"
sudo echo $WG_NODE_PRIVATE_KEY > "$WG_NODE_KEYS_DIR/${WG_NODE_INTERFACE}_privatekey"
sudo echo $WG_NODE_PUBLIC_KEY > "$WG_NODE_KEYS_DIR/${WG_NODE_INTERFACE}_publickey"

# Step 3: Create Configuration File
log_print INFO "Creating Configuration File..."

log_print INFO "First, create the Interface Part of the Configuration File."
log_print INFO "The Peers part will be populated by the systemd service."
sudo bash -c "cat > $WG_NODE_CONF <<EOF
[Interface]
PrivateKey = $WG_NODE_PRIVATE_KEY
Address = $WG_NODE_IP/24
ListenPort = $WG_NODE_LISTEN_PORT
EOF"

# Step 4: Enable and Start WireGuard
log_print INFO "Enable and Start WireGuard"
sudo systemctl enable wg-quick@$WG_NODE_INTERFACE
sudo systemctl start wg-quick@$WG_NODE_INTERFACE

log_print INFO "WireGuard Node is up and running!"
log_print INFO "Wireguard Node configuration is located at $WG_NODE_CONF"
log_print INFO "Wireguard Node keys are stored in $WG_NODE_KEYS_DIR"

# Check if the WireGuard interface is up and running
if ip link show $WG_NODE_INTERFACE up | grep -q "UP"; then
  log_print INFO "$WG_NODE_INTERFACE is up and running."
else
  log_print WARN "$WG_NODE_INTERFACE is down or not present."
fi

# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "wg-register-node.sh: Configuration done successfully in $ELAPSED seconds ."
