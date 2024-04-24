#!/bin/bash

# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
LOGFILE="/var/log/preinstall.$PID.log"

# Set up the logging for the script
sudo touch $LOGFILE
sudo chown $USER:$USER $LOGFILE

# All the output of this shell script is redirected to the LOGFILE
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>$LOGFILE 2>&1

# Find Architecture
ARCH_COMMAND=$(sudo arch)
AMD_ARCH="x86_64"
ARM_ARCH="aarch64"

if [ "$ARCH_COMMAND" = "$AMD_ARCH" ]; then
    ARCHITECTURE="amd64"
elif [ "$ARCH_COMMAND" = "$ARM_ARCH" ]; then
    ARCHITECTURE="arm64"
fi

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
log_print INFO "Preinstall (check_lock.$PID): Checking for apt lock"
while [ `ps aux | grep [l]ock_is_held | wc -l` != 0 ]; do
    echo "Lock_is_held $i"
    ps aux | grep [l]ock_is_held
    sleep 10
    ((i=i+10));
done
log_print INFO "Preinstall (check_lock.$PID): Exited the while loop, time spent: $i"
echo "ps aux | grep apt"
ps aux | grep apt
log_print INFO "Preinstall (check_lock.$PID): Waiting for lock task ended properly."
}

# Function to check for the wg command
check_wg_installed() {
    # Using command -v to check for the wg command
    if command -v wg >/dev/null 2>&1; then
        log_print INFO "Preinstall (check_wg_installed.$PID): WireGuard (wg) is installed."
        log_print INFO "Preinstall (check_wg_installed.$PID): Location: $(which wg)"
    else
        log_print INFO "Preinstall (check_wg_installed.$PID): WireGuard (wg) is not installed."
    fi
}

# Start the Configuration
log_print INFO "Preinstall ($PID): Configuration started!"
log_print INFO "Preinstall ($PID): Logs are saved at: $LOGFILE"


log_print INFO "Preinstall ($PID): Step 1: Adding modprobe br_netfilter and setting ip_forward = 1..."
# Modbprobe and ip_forward
sudo modprobe br_netfilter
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.conf
sudo sysctl -p

log_print INFO "Preinstall ($PID) Step 2: Installing wireguard and resolvconf"
Check_lock
# Step 1: Install WireGuard package
if ! command -v wg > /dev/null; then
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y resolvconf
fi

# Step 2: Check if Wireguard is installed
log_print INFO "Preinstall (check_wg_installed.$PID) Step 2: Checking if WireGuard (wg) is installed..."
check_wg_installed

# Check for lock
Check_lock

# Step 3: Update the package list
log_print INFO "Preinstall ($PID) Step 3: Updating the package list"
sudo apt-get update

# Check for lock
Check_lock
# Install curl
log_print INFO "Preinstall ($PID) Step 4: Installing ca-certificates curl"
sudo apt-get install -y ca-certificates curl || { log_print ERROR "Preinstall ($PID) Step 4: curl installation failed!"; exit $EXITCODE; }

# Check for lock
Check_lock

log_print INFO "Preinstall ($PID) Step 5: Installing /etc/apt/keyrings"
sudo install -m 0755 -d /etc/apt/keyrings

# Check for lock
Check_lock

# Adding Kubernetes Repo
log_print INFO "Preinstall ($PID) Step 6: Adding Kubernetes Repo"
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.26/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.26/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg || { log_print ERROR "Preinstall ($PID) Step 5: Kubernetes repo can't be added!"; exit $EXITCODE; }
sudo apt-get update

# Check for lock
Check_lock

# Install Kubernetes
log_print INFO "Preinstall ($PID) Step 7: Installing Kubernetes"
sudo apt-get install -y kubeadm=1.26.15-1.1 --allow-downgrades || { log_print ERROR "Preinstall ($PID) Step 6: kubeadm installation failed!"; exit $EXITCODE; }
sudo apt-get install -y kubelet=1.26.15-1.1 --allow-downgrades || { log_print ERROR "Preinstall ($PID) Step 6: kubectl installation failed!"; exit $EXITCODE; }
sudo apt-get install -y kubectl=1.26.15-1.1 --allow-downgrades || { log_print ERROR "Preinstall ($PID) Step 6: kubelet installation failed!"; exit $EXITCODE; }

# Install Containerd
log_print INFO "Preinstall ($PID) Step 8: Installing Containerd"
mkdir -p $HOME/k8s-deps
wget https://github.com/containerd/containerd/releases/download/v1.7.2/containerd-1.7.2-linux-$ARCHITECTURE.tar.gz -P $HOME/k8s-deps
tar xvf $HOME/k8s-deps/containerd-1.7.2-linux-$ARCHITECTURE.tar.gz
sudo tar Cxzvf /usr/local $HOME/k8s-deps/containerd-1.7.2-linux-$ARCHITECTURE.tar.gz
wget https://github.com/opencontainers/runc/releases/download/v1.1.3/runc.$ARCHITECTURE -P $HOME/k8s-deps
sudo install -m 755 $HOME/k8s-deps/runc.$ARCHITECTURE /usr/local/sbin/runc
wget https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-$ARCHITECTURE-v1.1.1.tgz -P $HOME/k8s-deps
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin $HOME/k8s-deps/cni-plugins-linux-$ARCHITECTURE-v1.1.1.tgz
sudo mkdir /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /etc/systemd/system/containerd.service
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

sudo systemctl restart containerd

sudo systemctl status containerd

# Holding upgrades for Kubernetes software (versions to updated manually)
log_print INFO "Preinstall ($PID) Step 9: Holding Packages"
sudo apt-mark hold kubeadm kubelet kubectl containerd

log_print INFO "Preinstall ($PID) Step 10: Checking Kubernetes versions"
kubeadm version     || { log_print ERROR "Preinstall ($PID) Step 9: kubeadm installation failed!"; exit $EXITCODE; }
kubelet --version   || { log_print ERROR "Preinstall ($PID) Step 9: kubelet installation failed!"; exit $EXITCODE; }
kubectl version
if [ $? -gt 1 ]; then
	log_print ERROR "Preinstall ($PID) Step 10: kubectl installation failed!"; exit $EXITCODE;
fi

# Turn off the swap memory
log_print INFO "Preinstall ($PID) Step 11: Turn off swap..."
if [ `grep Swap /proc/meminfo | grep SwapTotal: | cut -d" " -f14` == "0" ]; then
  log_print INFO "Preinstall ($PID) Step 11: The swap memory is Off"
else
  sudo swapoff –a || { log_print ERROR "Preinstall ($PID) Step 11: swap memory can't be turned off "; exit $EXITCODE; }
fi

log_print INFO "Preinstall ($PID) Step 12: Installing Helm..."

curl -fsSL -o $HOME/k8s-deps/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 $HOME/k8s-deps/get_helm.sh && $HOME/k8s-deps/get_helm.sh
# Add Cilium Helm Repo
helm repo add cilium https://helm.cilium.io/
helm repo update

# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "Preinstall ($PID) Step 13: k8s-preinstall.sh: Configuration done successfully in $ELAPSED seconds "
