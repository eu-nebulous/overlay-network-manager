#!/bin/bash

# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
LOGFILE="/var/log/wg-deregister-node.$PID.log"

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
    log_print WARN "Usage: $0 <SSH_USERNAME> <WG_NODE_INTERFACE>"
    exit 1
fi

# Script parameter
SSH_USERNAME="$1"
WG_NODE_INTERFACE="wg$2"

log_print INFO "Script Parameters: WG_NODE_INTERFACE=$WG_NODE_INTERFACE, SSH_USERNAME=$SSH_USERNAME"

# Step 1: Disable and stop the WireGuard service
log_print INFO "Disable and stop the WireGuard service"
sudo systemctl stop wg-quick@$WG_NODE_INTERFACE
sudo systemctl disable wg-quick@$WG_NODE_INTERFACE

# Step 2: Remove the WireGuard interface
log_print INFO "Remove the WireGuard interface"
sudo ip link delete $WG_NODE_INTERFACE

# Step 3: Remove OpenSSL Public Key
log_print INFO "Remove OpenSSL Public Key"
sed -i '/wireguard-pub/d' /home/$SSH_USERNAME/.ssh/authorized_keys

# Step 4: Remove Wireguard related directories
log_print INFO "Remove Wireguard related directories"
sudo rm -rf /etc/wireguard
sudo rm -rf /home/$SSH_USERNAME/wireguard

log_print INFO "WireGuard interface $WG_NODE_INTERFACE has been removed."

# Step 5: Remove Polling Systemd Service
log_print INFO "Remove Polling Systemd Service"
sudo systemctl stop onm_peers_polling_service
sudo systemctl disable onm_peers_polling_service
sudo rm -rf /usr/local/bin/onm_peers_polling_script.sh
sudo rm -rf /etc/systemd/system/onm_peers_polling_service.service
sudo systemctl daemon-reload
sudo systemctl reset-failed

# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "wg-deregister-node.sh: Configuration done successfully in $ELAPSED seconds "