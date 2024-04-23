#!/bin/bash

# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
LOGFILE="/var/log/k8s-master-init.$PID.log"

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

WIREGUARD_VPN_IP=`ip a | grep wg | grep inet | awk '{print $2}' | cut -d'/' -f1`

log_print INFO "k8s-master-init.sh ($PID): Initializing Kubernetes using kubeadm..."
# Init kubernetes
sudo kubeadm init --apiserver-advertise-address ${WIREGUARD_VPN_IP} --service-cidr 10.96.0.0/16 --pod-network-cidr 10.244.0.0/16

# Set kubeconfig file
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

log_print INFO "k8s-master-init.sh ($PID): Installing Cilium"
# Install Cilium with Wireguard parameters
helm install cilium cilium/cilium --namespace kube-system --set encryption.enabled=true --set encryption.type=wireguard

log_print INFO "k8s-master-init.sh ($PID): Installing Kubevela"
curl -fsSL -o $HOME/k8s-deps/kubevela_install.sh https://kubevela.io/script/install.sh && chmod 700 $HOME/k8s-deps/kubevela_install.sh && $HOME/k8s-deps/kubevela_install.sh

log_print INFO "k8s-master-init.sh ($PID): Save K8s join command to $HOME/k8s-deps"
# Save join command to specific path for the worker nodes to SCP
kubeadm token create --print-join-command > $HOME/k8s-deps/k8s-join-command.sh

# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "k8s-master-init.sh ($PID): k8s-master-init.sh: Configuration done successfully in $ELAPSED seconds "