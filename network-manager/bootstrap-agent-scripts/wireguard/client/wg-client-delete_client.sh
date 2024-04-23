#!/bin/bash

# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
LOGFILE="/var/log/wg-client-delete_client.$PID.log"

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
if [ "$#" -ne 2 ]; then
    log_print WARN "Usage: $0 <SSH_USERNAME> <WG_INTERFACE_NAME>"
    exit 1
fi

# Script parameter
SSH_USERNAME="$1"
WG_INTERFACE_NAME="$2"

log_print INFO "Script Parameters: SSH_USERNAME=$SSH_USERNAME, WG_INTERFACE_NAME=$WG_INTERFACE_NAME"

log_print INFO "Stop and Disable WireGuard Interface"
# Step 1: Stop and Disable WireGuard Interface
sudo systemctl stop wg-quick@$WG_INTERFACE_NAME
sudo systemctl disable wg-quick@$WG_INTERFACE_NAME

log_print INFO "Wireguard packages have been removed."

log_print INFO "Remove Wireguard related directories"
# Step 2: Remove Wireguard related directories
sudo rm -rf /etc/wireguard
sudo rm -rf /home/$SSH_USERNAME/wireguard

log_print INFO "WireGuard configuration files removed."

log_print INFO "Remove WG OpenSSL Private Key"
# Step 3: Remove WG OpenSSL Private Key
sudo rm -rf /home/$SSH_USERNAME/wg-private-key.key

log_print INFO "Remove OpenSSL Public Key"
# Step 4: Remove OpenSSL Public Key
sed -i '/wireguard-pub/d' /home/$SSH_USERNAME/.ssh/authorized_keys

# Step 5: Remove OpenSSL Public Key
sudo ip link delete $WG_INTERFACE_NAME

log_print INFO "WireGuard client $WG_INTERFACE_NAME has been stopped and disabled."

# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "wg-client-delete_client.sh: Configuration done successfully in $ELAPSED seconds "
