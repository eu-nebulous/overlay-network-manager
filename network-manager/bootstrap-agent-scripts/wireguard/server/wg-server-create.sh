#!/bin/bash

# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
LOGFILE="/var/log/wg-server-create.$PID.log"

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
    log_print WARN "Usage: $0 <WG_Server_Private_Key> <WG_Server_Public_Key> <WG_Server_IP>"
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

log_print INFO "Script Parameters: WG_SERVER_PRIVATE_KEY=$WG_SERVER_PRIVATE_KEY, WG_SERVER_PUBLIC_KEY=$WG_SERVER_PUBLIC_KEY,
                WG_INTERFACE=$WG_INTERFACE, SERVER_IP=$SERVER_IP, LISTEN_PORT=$LISTEN_PORT, WG_DIR=$WG_DIR,
                SERVER_KEYS_DIR=$SERVER_KEYS_DIR, SERVER_CONF=$SERVER_CONF"

log_print INFO "Create directories for keys and configuration"
# Step 1: Create directories for keys and configuration
sudo mkdir -p "$SERVER_KEYS_DIR"
sudo mkdir -p "$WG_DIR"

log_print INFO "Generate Server Keys"
# Step 2: Generate Server Keys
sudo echo $WG_SERVER_PRIVATE_KEY > "$SERVER_KEYS_DIR/${WG_INTERFACE}_privatekey"
sudo echo $WG_SERVER_PUBLIC_KEY > "$SERVER_KEYS_DIR/${WG_INTERFACE}_publickey"
server_private_key=$(sudo cat "$SERVER_KEYS_DIR/${WG_INTERFACE}_privatekey")

log_print INFO "Create Server Configuration File"
# Step 3: Create Server Configuration File
sudo bash -c "cat > $SERVER_CONF <<EOF
[Interface]
Address = $SERVER_IP
ListenPort = $LISTEN_PORT
PrivateKey = $server_private_key
SaveConfig = true
EOF"

log_print INFO "Enable and Start WireGuard"
# Step 4: Enable and Start WireGuard
sudo systemctl enable wg-quick@$WG_INTERFACE
sudo systemctl start wg-quick@$WG_INTERFACE

log_print INFO "WireGuard server is up and running!"
log_print INFO "Server configuration is located at $SERVER_CONF"
log_print INFO "Server keys are stored in $SERVER_KEYS_DIR"

# Check if the WireGuard interface is up and running
if ip link show $WG_INTERFACE up | grep -q "UP"; then
  log_print INFO "$WG_INTERFACE is up and running."
else
  log_print WARN "$WG_INTERFACE is down or not present."
fi

# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "wg-server-create.sh: Configuration done successfully in $ELAPSED seconds "
