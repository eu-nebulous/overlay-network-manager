#!/bin/sh

WIREGUARD_VPN_IP=`ip a | grep wg | grep inet | awk '{print $2}' | cut -d'/' -f1`

# Init kubernetes
sudo kubeadm init --apiserver-advertise-address ${WIREGUARD_VPN_IP} --service-cidr 10.96.0.0/16 --pod-network-cidr 10.244.0.0/16

# Set kubeconfig file
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Add Cilium Helm Repo
helm repo add cilium https://helm.cilium.io/
helm repo update

# Install Cilium with Wireguard parameters
helm install cilium cilium/cilium --namespace kube-system --set encryption.enabled=true --set encryption.type=wireguard

# Add KubeVela Helm repository and update
echo "Setting up KubeVela..."
helm repo add kubevela https://kubevelacharts.oss-cn-hangzhou.aliyuncs.com/core
helm repo update
helm install --create-namespace -n vela-system kubevela kubevela/vela-core --wait

# Save join command to specific path for the worker nodes to SCP
kubeadm token create --print-join-command > $HOME/k8s-join-command.sh