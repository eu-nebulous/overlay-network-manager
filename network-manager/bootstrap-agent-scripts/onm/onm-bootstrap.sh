#!/bin/bash

# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
LOGFILE="/var/log/onm-bootstrap.$PID.log"

# Set up the logging for the script
sudo touch $LOGFILE
sudo chown $USER:$USER $LOGFILE

# All the output of this shell script is redirected to the LOGFILE
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>$LOGFILE 2>&1

# Find Resource Architecture
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
    log_print INFO "onm-bootstrap($PID): Checking for apt lock"
    while [ `ps aux | grep [l]ock_is_held | wc -l` != 0 ]; do
      log_print INFO "onm-bootstrap($PID): Lock_is_held $i"
      ps aux | grep [l]ock_is_held
      sleep 10
      ((i=i+10));
  done

  log_print INFO "onm-bootstrap($PID): Exited the while loop, time spent: $i"
  log_print INFO "onm-bootstrap($PID): ps aux | grep apt"
  ps aux | grep apt
  log_print INFO "onm-bootstrap($PID): Waiting for lock task ended properly."
}

# Function to check for the wg command
check_wg_installed() {
    log_print "onm-bootstrap($PID): Checking if WireGuard (wg) is installed..."

    # Using command -v to check for the wg command
    if command -v wg >/dev/null 2>&1; then
        log_print "onm-bootstrap($PID): WireGuard (wg) is installed."
        log_print "onm-bootstrap($PID): Location: $(which wg)"
    else
        log_print "onm-bootstrap($PID): WireGuard (wg) is not installed."
    fi
}

createSystemdService() {
  # Define paths and filenames
  log_print INFO "onm-bootstrap ($PID): Define paths and filenames for systemd service"
  SCRIPT_PATH="/usr/local/bin/onm_peers_polling_script.sh"
  SERVICE_PATH="/etc/systemd/system/onm_peers_polling_service.service"

  WIREGUARD_VPN_IP=`ip a | grep wg | grep inet | awk '{print $2}' | cut -d'/' -f1`;

  API_ENDPOINT=$ONM_URL/api/v1/node/peers/$WIREGUARD_VPN_IP/$APPLICATION_UUID

  # Create Systemd Service for Topology Peer Sync (Fetch Peers List based on Application UUID)
  # Create script for polling an API(/peers/${WIREGUARD_VPN_IP}/${APPLICATION_UUID})
  # and every time get the node's peers, do:
  # 1) sed -i '7,$d' /etc/wireguard/wg${WIREGUARD_VPN_IP}
  # 2) Loop peers, update the /etc/wireguard/wg${WIREGUARD_VPN_IP} file
  # 3) sudo systemctl restart wg-quick@wg${WIREGUARD_VPN_IP}
  # Create the polling script
  sudo bash -c "cat > $SCRIPT_PATH <<'EOF'
#!/bin/bash

while true; do
  sleep 5
  sed -i '6,\$d' /etc/wireguard/wg$WIREGUARD_VPN_IP.conf

  peers_json=\$(curl -s -X GET \"$API_ENDPOINT\")

  echo \"Running as user: \$(whoami)\"
  echo \"Checking Peers($API_ENDPOINT) for $WIREGUARD_VPN_IP with Application UUID $APPLICATION_UUID\"

  length=\$(echo \$peers_json | jq \". | length\" 2>&1)

  # Check if the jq command succeeded
  if [[ \$? -ne 0 ]]; then
    echo \"jq error: \$length\"
  else
    if [ \"\$length\" -eq 0 ]; then
      echo \"The peers list is empty. No peers to append.\"
      systemctl restart wg-quick@wg$WIREGUARD_VPN_IP
      continue;
    else
      echo \"Peers are \$peers_json\"
    fi
  fi

  echo \"\$peers_json\" | jq -c \".[]\" | while read -r peer; do
    public_key=\$(echo \$peer | jq -r '.wireguardPublicKey')
    endpoint=\$(echo \$peer | jq -r '.publicIp'):51820
    allowed_ips=\$(echo \$peer | jq -r '.wireguardIp')/32
    persistent_keepalive=25

    echo \"\" >> /etc/wireguard/wg$WIREGUARD_VPN_IP.conf
    # Create the Peer entry
    bash -c \"cat >> /etc/wireguard/wg$WIREGUARD_VPN_IP.conf <<'EOF'
[Peer]
PublicKey = \$public_key
Endpoint = \$endpoint
AllowedIPs = \$allowed_ips
PersistentKeepalive = \$persistent_keepalive
EOF\"
  done

  echo \"Restarting wireguard service wg-quick@wg$WIREGUARD_VPN_IP.\"
  systemctl restart wg-quick@wg$WIREGUARD_VPN_IP
  echo \"Successfully restarted wireguard service wg-quick@wg$WIREGUARD_VPN_IP.\"
done
EOF"

  # Make the polling script executable
  log_print INFO "onm-bootstrap ($PID): Make the polling systemd script executable"
  sudo chmod +x $SCRIPT_PATH

  # Create the systemd service file
  log_print INFO "onm-bootstrap ($PID): Create the systemd polling service file"
  sudo bash -c "cat > $SERVICE_PATH <<'EOF'
[Unit]
Description=Polling Service that fetches peers list based on Application UUID
After=network.target

[Service]
ExecStart=$SCRIPT_PATH
Restart=always
User=root
Group=root
Environment=PATH=/usr/bin:/usr/local/bin

[Install]
WantedBy=multi-user.target
EOF"

  # Reload systemd to recognize the new service
  log_print INFO "onm-bootstrap ($PID): Reload systemd to recognize onm_peers_polling_service"
  sudo systemctl daemon-reload

  # Enable the service to start on boot
  log_print INFO "onm-bootstrap ($PID): Enable onm_peers_polling_service to start on boot"
  sudo systemctl enable onm_peers_polling_service.service

  # Start the service
  log_print INFO "onm-bootstrap ($PID): Start the onm_peers_polling_service"
  sudo systemctl start onm_peers_polling_service.service

  # Display the status of the service
  log_print INFO "onm-bootstrap ($PID): Display the status of the onm_peers_polling_service"
  sudo systemctl status onm_peers_polling_service.service
}

# "CREATE" or "DELETE" Overlay Node
ACTION=$1
# Application UUID
APPLICATION_UUID=$2
# Overlay Network Manager Public IP
ONM_URL=$3
# Get the public IP
public_ip=${4:-$(curl -s http://httpbin.org/ip | grep -oP '(?<="origin": ")[^"]*')}
# SSH Port
SSH_PORT=${5:-22}

# Get the currently logged in user (assuming single user login)
logged_in_user=$(whoami)

# Start the Configuration
log_print INFO "onm-bootstrap ($PID): Configuration started!"
log_print INFO "onm-bootstrap ($PID): Logs are saved at: $LOGFILE"

log_print INFO "onm-bootstrap($PID): Starting onm-bootstrap with the following parameters: ACTION=$ACTION,
                APPLICATION_UUID=$APPLICATION_UUID, ONM_URL=$ONM_URL, PUBLIC_IP=$public_ip,
                LOGGED_IN_USER=$logged_in_user, SSH_PORT=$SSH_PORT"

# Check Action
if [ "$ACTION" == "CREATE" ]; then
  log_print INFO "onm-bootstrap($PID): Updating apt..."
  Check_lock

  sudo apt-get update

  # Check if the architecture is arm64
  if [ "$ARCHITECTURE" = "arm64" ]; then
      KERNEL_VERSION=$(uname -r)
      LINUX_MODULE="linux-modules-extra-${KERNEL_VERSION}"
      log_print INFO "onm-bootstrap($PID): Architecture is $ARCHITECTURE. Installing... $LINUX_MODULE"

      Check_lock
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y $LINUX_MODULE
  fi

  log_print INFO "onm-bootstrap($PID): Installing wireguard and resolvconf..."

  Check_lock
  # Install WireGuard package and jq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y resolvconf
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y jq

  # Check if Wireguard is installed
  check_wg_installed

  log_print INFO "onm-bootstrap($PID): Creating Wireguard folder to home directory..."
  # Create Wireguard Folder to accept the wireguard scripts
  mkdir -p /home/${logged_in_user}/wireguard

  log_print INFO "onm-bootstrap($PID): Creating OpenSSH Public/Private Key Pair..."
  # Create OpenSSH Public/Private Key files
  ssh-keygen -C wireguard-pub -t rsa -b 4096 -f /home/${logged_in_user}/wireguard/wireguard -N ""

  # Checking existence of ~/.ssh/authorized_keys
  SSH_DIR_NAME="/home/${logged_in_user}/.ssh"
  log_print INFO "onm-bootstrap($PID): Checking existence of ~/.ssh/authorized_keys"
  if [ -d "$SSH_DIR_NAME" ]; then
    log_print INFO "Directory $SSH_DIR_NAME already exists."
  else
    log_print INFO "Directory $SSH_DIR_NAME does not exist. Creating it now."
    mkdir -p /home/${logged_in_user}/.ssh && chmod 700 /home/${logged_in_user}/.ssh
    if [ $? -eq 0 ]; then
      touch $SSH_DIR_NAME/authorized_keys && chmod 600 $SSH_DIR_NAME/authorized_keys
    else
      log_print WARN "Failed to create directory $SSH_DIR_NAME."
      exit 1
    fi
  fi

  log_print INFO "onm-bootstrap($PID): Moving wireguard.pub file to authorized_keys file..."
  cat /home/${logged_in_user}/wireguard/wireguard.pub >> /home/${logged_in_user}/.ssh/authorized_keys

  PRIVATE_KEY_FILE=$(cat /home/${logged_in_user}/wireguard/wireguard | base64 | tr '\n' ' ')

  PAYLOAD=$(cat <<EOF
  {
    "privateKeyBase64": "${PRIVATE_KEY_FILE}",
    "publicKey": "$(</home/${logged_in_user}/wireguard/wireguard.pub)",
    "publicIp": "${public_ip}",
    "sshUsername": "${logged_in_user}",
    "sshPort": "$SSH_PORT",
    "applicationUUID": "${APPLICATION_UUID}"
  }
EOF
  )

  log_print INFO "onm-bootstrap($PID): Current Payload is: $PAYLOAD"

  log_print INFO "onm-bootstrap($PID): Executing API Call: ${ONM_URL}/api/v1/node/create....."
  curl -v -X POST -H "Content-Type: application/json" -d "$PAYLOAD" ${ONM_URL}/api/v1/node/create

  log_print INFO "onm-bootstrap($PID): Just finished! Now I'm creating the polling systemd service..."
  createSystemdService
  log_print INFO "onm-bootstrap($PID): Systemd Service created successfully!"

elif [ "$ACTION" == "DELETE" ]; then
  WIREGUARD_VPN_IP=`ip a | grep wg | grep inet | awk '{print $2}' | cut -d'/' -f1`;
  log_print INFO "onm-bootstrap($PID): Executing API Call: ${ONM_URL}/api/v1/node/delete/${WIREGUARD_VPN_IP}/${APPLICATION_UUID}....."
  curl -v -X DELETE -H "Content-Type: application/json" ${ONM_URL}/api/v1/node/delete/${WIREGUARD_VPN_IP}/${APPLICATION_UUID}
  log_print INFO "onm-bootstrap($PID): Just finished! The Wireguard Interface has been deleted."
fi

# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "onm-bootstrap($PID): onm-bootstrap.sh: Configuration done successfully in $ELAPSED seconds "
