#!/bin/sh

# Capture the second argument as the hostname
HOSTNAME=$1
# Set the hostname
echo "Setting hostname to '$HOSTNAME'..."
sudo hostnamectl set-hostname "$HOSTNAME"

WIREGUARD_VPN_IP=`ip a | grep wg | grep inet | awk '{print $2}' | cut -d'/' -f1`

# Create k8s directory to host all appropriate files
mkdir -p $HOME/k8s

# Update Repository
sudo DEBIAN_FRONTEND=noninteractive apt update

# Install libraries
sudo DEBIAN_FRONTEND=noninteractive apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common

# Docker Keys
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update Repositories again
sudo DEBIAN_FRONTEND=noninteractive apt update

# Install Docker
sudo DEBIAN_FRONTEND=noninteractive apt install -y docker-ce=5:20.10.22~3-0~ubuntu-jammy docker-ce-cli=5:20.10.22~3-0~ubuntu-jammy containerd.io=1.6.14-1
sudo usermod -aG docker $USER
sudo systemctl enable docker
sudo systemctl start docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo systemctl restart docker

# Kubernetes Keys
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/google-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-archive-keyring.gpg] http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

# Update Repositories
sudo DEBIAN_FRONTEND=noninteractive apt-get update

# Install K8s CLI tools
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y kubeadm=1.22.4-00 kubelet=1.22.4-00 kubectl=1.22.4-00
sudo DEBIAN_FRONTEND=noninteractive apt-mark hold kubeadm kubelet kubectl
echo "KUBELET_EXTRA_ARGS=--node-ip=${WIREGUARD_VPN_IP}" | sudo tee -a /etc/default/kubelet
sudo systemctl restart kubelet

# Disable Swap
sudo swapoff -a
sudo  sed -i '/ swap / s/^/#/' /etc/fstab

# Set hostname label to K8s Node
sudo kubectl label nodes "$HOSTNAME" disktype=ssd

# Install Helm Package Manager
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
sudo chmod 700 get_helm.sh
sudo $HOME/get_helm.sh

echo "Configuration complete."
