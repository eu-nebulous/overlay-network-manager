#!/bin/bash

# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
LOGFILE="/var/log/wg-server-delete.$PID.log"

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

# Script parameter: WireGuard interface name (e.g., wg0)
WG_INTERFACE=wg0

# Script parameter
SSH_USERNAME="$1"

log_print INFO "Script Parameters: WG_INTERFACE=$WG_INTERFACE, SSH_USERNAME=$SSH_USERNAME"

log_print INFO "Disable and stop the WireGuard service"
# Step 1: Disable and stop the WireGuard service
sudo systemctl stop wg-quick@$WG_INTERFACE
sudo systemctl disable wg-quick@$WG_INTERFACE

log_print INFO "Remove the WireGuard interface"
# Step 2: Remove the WireGuard interface
sudo ip link delete $WG_INTERFACE

log_print INFO "Remove OpenSSL Public Key"
# Step 3: Remove OpenSSL Public Key
sed -i '/wireguard-pub/d' /home/$SSH_USERNAME/.ssh/authorized_keys

log_print INFO "Remove Wireguard related directories"
# Step 4: Remove Wireguard related directories
sudo rm -rf /etc/wireguard
sudo rm -rf /home/$SSH_USERNAME/wireguard

log_print INFO "WireGuard server $WG_INTERFACE has been removed."

# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "wg-server-delete.sh: Configuration done successfully in $ELAPSED seconds "