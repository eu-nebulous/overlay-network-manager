#!/bin/bash

# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
EXITCODE=$PID
LOGFILE="/var/log/k8s-preinstall.$PID.log"

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

# Find Architecture
ARCH_COMMAND=$(sudo arch)
AMD_ARCH="x86_64"
ARM_ARCH="aarch64"

if [ "$ARCH_COMMAND" = "$AMD_ARCH" ]; then
    ARCHITECTURE="amd64"
elif [ "$ARCH_COMMAND" = "$ARM_ARCH" ]; then
    ARCHITECTURE="arm64"
fi

# Check for lock
Check_lock

# Update the package list
log_print INFO "Updating the package list."
sudo apt-get update

# Start the Configuration
log_print INFO "Configuration started!"
log_print INFO "Logs are saved at: $LOGFILE"

# Check for lock
Check_lock
# Install curl
log_print INFO "Installing curl"
sudo apt-get install -y curl || { log_print ERROR "curl installation failed!"; exit $EXITCODE; }

# Adding Kubernetes Repo
log_print INFO "Adding Kubernetes Repo"
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.26/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.26/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg || { log_print ERROR "Kubernetes repo can't be added!"; exit $EXITCODE; }
sudo apt-get update

# Check for lock
Check_lock
# Install Kubernetes
log_print INFO "Installing Kubernetes"
sudo apt-get install -y kubeadm=1.26.15-1.1 --allow-downgrades || { log_print ERROR "kubeadm installation failed!"; exit $EXITCODE; }
sudo apt-get install -y kubelet=1.26.15-1.1 --allow-downgrades || { log_print ERROR "kubectl installation failed!"; exit $EXITCODE; }
sudo apt-get install -y kubectl=1.26.15-1.1 --allow-downgrades || { log_print ERROR "kubelet installation failed!"; exit $EXITCODE; }

# Install Containerd
wget https://github.com/containerd/containerd/releases/download/v1.7.2/containerd-1.7.2-linux-$ARCHITECTURE.tar.gz
tar xvf containerd-1.7.2-linux-$ARCHITECTURE.tar.gz
sudo tar Cxzvf /usr/local containerd-1.7.2-linux-$ARCHITECTURE.tar.gz
wget https://github.com/opencontainers/runc/releases/download/v1.1.3/runc.$ARCHITECTURE
sudo install -m 755 runc.$ARCHITECTURE /usr/local/sbin/runc
wget https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-$ARCHITECTURE-v1.1.1.tgz
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-$ARCHITECTURE-v1.1.1.tgz
sudo mkdir /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /etc/systemd/system/containerd.service
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

sudo systemctl restart containerd

sudo systemctl status containerd

# Holding upgrades for Kubernetes software (versions to updated manually)
sudo apt-mark hold kubeadm kubelet kubectl containerd

WIREGUARD_VPN_IP=`ip a | grep wg | grep inet | awk '{print $2}' | cut -d'/' -f1`
echo "KUBELET_EXTRA_ARGS=--node-ip=${WIREGUARD_VPN_IP} --container-runtime-endpoint=unix:///run/containerd/containerd.sock" | sudo tee -a /etc/default/kubelet
sudo systemctl restart kubelet

log_print INFO "Checking Kubernetes versions"

kubeadm version     || { log_print ERROR "kubeadm installation failed!"; exit $EXITCODE; }
kubelet --version   || { log_print ERROR "kubelet installation failed!"; exit $EXITCODE; }
kubectl version
if [ $? -gt 1 ]; then
	log_print ERROR "kubectl installation failed!"; exit $EXITCODE;
fi

# Turn off the swap memory
if [ `grep Swap /proc/meminfo | grep SwapTotal: | cut -d" " -f14` == "0" ]; then
  log_print INFO "The swap memory is Off"
else
  sudo swapoff –a || { log_print ERROR "swap memory can't be turned off "; exit $EXITCODE; }
fi

log_print INFO "Installing Helm..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh
# Add Cilium Helm Repo
helm repo add cilium https://helm.cilium.io/
helm repo update

# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "k8s-preinstall.sh: Configuration done successfully in $ELAPSED seconds "