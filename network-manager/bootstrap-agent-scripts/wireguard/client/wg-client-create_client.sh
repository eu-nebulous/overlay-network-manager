#!/bin/bash

# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
LOGFILE="/var/log/wg-client-create_client.$PID.log"

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
if [ "$#" -ne 5 ]; then
    log_print WARN "Usage: $0 <WORKER_SSH_USERNAME> <OPENSSL_PRIVATE_KEY> <SERVER_IP> <CLIENT_NAME> <MASTER_SSH_USERNAME>"
    exit 1
fi

# Script parameter
WORKER_SSH_USERNAME="$1"
OPENSSL_PRIVATE_KEY="$2"
SERVER_IP="$3"
CLIENT_NAME="$4"
MASTER_SSH_USERNAME="$5"
WG_DIR="/etc/wireguard"

log_print INFO "Script Parameters: WORKER_SSH_USERNAME=$WORKER_SSH_USERNAME, OPENSSL_PRIVATE_KEY=$OPENSSL_PRIVATE_KEY,
                SERVER_IP=$SERVER_IP, CLIENT_NAME=$CLIENT_NAME, MASTER_SSH_USERNAME=$MASTER_SSH_USERNAME"

# Step 1: Create director for configuration
sudo mkdir -p "$WG_DIR"

log_print INFO "Base64 Decode the OpenSSH Private Key file"
# Step 1: Base64 Decode the OpenSSH Private Key file
echo $OPENSSL_PRIVATE_KEY | base64 -d --ignore-garbage > /home/$WORKER_SSH_USERNAME/wg-private-key.key
chmod 400 /home/$WORKER_SSH_USERNAME/wg-private-key.key

log_print INFO "Secure Copy to WG Server to get your conf file"

# Step 2: Secure Copy to WG Server to get your conf file
sudo scp -o StrictHostKeyChecking=no -i /home/$WORKER_SSH_USERNAME/wg-private-key.key $MASTER_SSH_USERNAME@$SERVER_IP:/home/$MASTER_SSH_USERNAME/wireguard/clients/$CLIENT_NAME/$CLIENT_NAME.conf /etc/wireguard/$CLIENT_NAME.conf

log_print INFO "Enable and Start WireGuard Client Interface"
# Step 3: Enable and Start WireGuard Client Interface
sudo systemctl enable wg-quick@$CLIENT_NAME
sudo systemctl start wg-quick@$CLIENT_NAME

log_print INFO "WireGuard client configured and started for $CLIENT_NAME"

# Check if the WireGuard interface is up and running
if ip link show $CLIENT_NAME up | grep -q "UP"; then
  log_print INFO "$CLIENT_NAME is up and running."
else
  log_print WARN "$CLIENT_NAME is down or not present."
fi

# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "wg-client-create_client.sh: Configuration done successfully in $ELAPSED seconds "