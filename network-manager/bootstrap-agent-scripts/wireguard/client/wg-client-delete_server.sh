#!/bin/bash

# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
LOGFILE="/var/log/wg-client-delete_server.$PID.log"

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

# Check if the client public key is provided
if [ "$#" -ne 3 ]; then
    log_print WARN "Usage: $0 <Client_Name> <Client_PublicKey> <SSH_Username>"
    exit 1
fi

# Script parameter
SERVER_NAME="wg0"
CLIENT_NAME="$1"
CLIENT_PUBLIC_KEY="$2"
SSH_USERNAME="$3"

log_print INFO "Script Parameters: SERVER_NAME=$SERVER_NAME, CLIENT_NAME=$CLIENT_NAME,
                CLIENT_PUBLIC_KEY=$CLIENT_PUBLIC_KEY, SSH_USERNAME=$SSH_USERNAME"

log_print INFO "Remove the client configuration from the server"
# Step 1: Remove the client configuration from the server
sudo wg set ${SERVER_NAME} peer ${CLIENT_PUBLIC_KEY} remove

log_print INFO "Remove the client config file"
# Step 2: Remove the client config file
sudo rm -rf /etc/wireguard/clients/${CLIENT_NAME}
sudo rm -rf /home/$SSH_USERNAME/wireguard/clients/${CLIENT_NAME}

log_print INFO "Restart WireGuard to apply changes"
# Step 3: Restart WireGuard to apply changes
sudo systemctl restart wg-quick@${SERVER_NAME}

log_print INFO "Client with public key $CLIENT_PUBLIC_KEY has been removed from the server configuration."

# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "wg-client-delete_server.sh: Configuration done successfully in $ELAPSED seconds "