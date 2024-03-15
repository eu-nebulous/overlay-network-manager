#!/bin/sh

# Define the original and the copy paths for the kubeconfig file
ORIGINAL_KUBECONFIG_PATH="$HOME/.kube/config"
KUBECONFIG_COPY_PATH="$HOME/.kube/config-copy"

# Copy the original kubeconfig file to a new location
if [ -f "$ORIGINAL_KUBECONFIG_PATH" ]; then
    cp "$ORIGINAL_KUBECONFIG_PATH" "$KUBECONFIG_COPY_PATH"
    echo "Kubeconfig file copied to $KUBECONFIG_COPY_PATH."
else
    echo "Original kubeconfig file not found at $ORIGINAL_KUBECONFIG_PATH."
    exit 1
fi

# Create the configmap from the copied kubeconfig file
kubectl create configmap kubeconfig --from-file=config=$KUBECONFIG_COPY_PATH
if [ $? -eq 0 ]; then
    echo "ConfigMap created successfully."
else
    echo "Failed to create ConfigMap."
    exit 1
fi

# Directory to store the YAML files
REPO_URL="https://gitlab.ubitech.eu/nebulous/use-cases/k8s-gatekeeper/-/raw/origin/config"

# Create the directory if it doesn't exist
CONFIG_DIR=$HOME/k8s/config
mkdir -p $CONFIG_DIR

# List of configuration files to download
CONFIG_FILES="rbac.yaml webhook_deployment.yaml webhook_internal.yaml auth.casbin.org_casbinmodels.yaml auth.casbin.org_casbinpolicies.yaml"

# Download the configuration files
for file in $CONFIG_FILES; do
    echo "WGET file: $file"
    wget -O "$CONFIG_DIR/$file" "$REPO_URL/$file"
    if [ $? -ne 0 ]; then
        echo "Failed to download $file."
        exit 1
    fi
done

# apply the downloaded configurations with delay
DELAY=5
for file in $CONFIG_FILES; do
    kubectl apply -f "$CONFIG_DIR/$file"
    sleep $DELAY
done

echo "All configurations applied successfully."