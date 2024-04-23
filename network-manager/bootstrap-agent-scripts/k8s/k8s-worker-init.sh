#!/bin/sh

# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
LOGFILE="/var/log/k8s-worker-init.$PID.log"

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

MASTER_IP=$1
MASTER_USERNAME=$2

log_print INFO "k8s-worker-init.sh ($PID): SCP to Master Node to get the k8s-join-command"
# Join Kubernetes Cluster
sudo scp -o StrictHostKeyChecking=no -i $HOME/wg-private-key.key $MASTER_USERNAME@$MASTER_IP:/home/$MASTER_USERNAME/k8s-deps/k8s-join-command.sh /home/$USER/k8s-deps/k8s-join-command.sh

sudo chmod +x $HOME/k8s-deps/k8s-join-command.sh

log_print "k8s-worker-init.sh ($PID): Executing k8s-join-command.sh to join the cluster"
sudo $HOME/k8s-deps/k8s-join-command.sh

# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "k8s-worker-init.sh ($PID): k8s-worker-init.sh: Configuration done successfully in $ELAPSED seconds "