#!/bin/bash

# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
LOGFILE="/var/log/onm-preinstall.$PID.log"

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

# A function to check for the apt lock
Check_lock() {
i=0
log_print INFO "Checking for apt lock"
while [ `ps aux | grep [l]ock_is_held | wc -l` != 0 ]; do
    echo "Lock_is_held $i"
    ps aux | grep [l]ock_is_held
    sleep 10
    ((i=i+10));
done
log_print INFO "Exited the while loop, time spent: $i"
echo "ps aux | grep apt"
ps aux | grep apt
log_print INFO "Waiting for lock task ended properly."
}

# Function to check for the wg command
check_wg_installed() {
    echo "Checking if WireGuard (wg) is installed..."

    # Using command -v to check for the wg command
    if command -v wg >/dev/null 2>&1; then
        echo "WireGuard (wg) is installed."
        echo "Location: $(which wg)"
    else
        echo "WireGuard (wg) is not installed."
    fi
}

log_print INFO "Installing wireguard and resolvconf"

Check_lock
# Step 1: Install WireGuard package
if ! command -v wg > /dev/null; then
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y resolvconf
fi

# Step 2: Check if Wireguard is installed
check_wg_installed

# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "onm-preinstall.sh: Configuration done successfully in $ELAPSED seconds "