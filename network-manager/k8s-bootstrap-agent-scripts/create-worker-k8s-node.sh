#!/bin/sh

MASTER_IP=$1
MASTER_USERNAME=$2

# Join Kubernetes Cluster
sudo scp -o StrictHostKeyChecking=no -i $HOME/wg-private-key.key $MASTER_USERNAME@$MASTER_IP:/home/$MASTER_USERNAME/k8s-join-command.sh /home/$USER/k8s/k8s-join-command.sh

sudo chmod +x $HOME/k8s/k8s-join-command.sh

sudo $HOME/k8s/k8s-join-command.sh
