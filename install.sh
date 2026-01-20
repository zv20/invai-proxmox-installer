#!/usr/bin/env bash

# Inventory Management System - Proxmox Automated Installer
# This script creates an LXC container and installs the inventory app automatically

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default configuration
DEFAULT_CTID="200"
DEFAULT_HOSTNAME="inventory-app"
DEFAULT_DISK_SIZE="4"
DEFAULT_MEMORY="512"
DEFAULT_CORES="1"
DEFAULT_BRIDGE="vmbr0"
APP_PORT="3000"

# GitHub repository
GITHUB_REPO="https://github.com/zv20/invai.git"

# Banner
function banner() {
    clear
    echo -e "${CYAN}"
    echo "═══════════════════════════════════════════════════════════"
    echo "    📦 Inventory Management System - Proxmox Installer"
    echo "═══════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

# Check if running on Proxmox
function check_proxmox() {
    if ! command -v pveversion &> /dev/null; then
        echo -e "${RED}✖ Error: This script must be run on a Proxmox VE host!${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Running on Proxmox VE $(pveversion | grep -oP 'pve-manager/\K[0-9.]+')${NC}"
}

# Check if running as root
function check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}✖ This script must be run as root${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Running with root privileges${NC}"
}

# Get user input with defaults
function get_user_input() {
    echo -e "\n${YELLOW}📝 Container Configuration${NC}"
    echo -e "${BLUE}Press Enter to use default values shown in [brackets]${NC}\n"
    
    # Container ID
    while true; do
        read -p "Container ID [$DEFAULT_CTID]: " CTID
        CTID=${CTID:-$DEFAULT_CTID}
        
        if pct status $CTID &>/dev/null; then
            echo -e "${RED}✖ Container $CTID already exists!${NC}"
        else
            break
        fi
    done
    
    # Hostname
    read -p "Hostname [$DEFAULT_HOSTNAME]: " HOSTNAME
    HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}
    
    # Root Password
    echo -e "\n${YELLOW}🔐 Set Root Password for Container${NC}"
    echo -e "${BLUE}This will allow you to log in to the container${NC}"
    while true; do
        read -s -p "Enter root password (leave empty to skip): " ROOT_PASSWORD
        echo
        if [ -z "$ROOT_PASSWORD" ]; then
            echo -e "${YELLOW}⚠️  No password set. Use 'pct enter $CTID' to access container${NC}"
            break
        fi
        read -s -p "Confirm root password: " ROOT_PASSWORD_CONFIRM
        echo
        if [ "$ROOT_PASSWORD" = "$ROOT_PASSWORD_CONFIRM" ]; then
            echo -e "${GREEN}✓ Password set successfully${NC}"
            break
        else
            echo -e "${RED}✖ Passwords don't match. Try again.${NC}"
        fi
    done
    
    # Disk Size
    read -p "Disk Size in GB [$DEFAULT_DISK_SIZE]: " DISK_SIZE
    DISK_SIZE=${DISK_SIZE:-$DEFAULT_DISK_SIZE}
    
    # Memory
    read -p "Memory in MB [$DEFAULT_MEMORY]: " MEMORY
    MEMORY=${MEMORY:-$DEFAULT_MEMORY}
    
    # CPU Cores
    read -p "CPU Cores [$DEFAULT_CORES]: " CORES
    CORES=${CORES:-$DEFAULT_CORES}
    
    # Network Bridge
    read -p "Network Bridge [$DEFAULT_BRIDGE]: " BRIDGE
    BRIDGE=${BRIDGE:-$DEFAULT_BRIDGE}
    
    # Network Configuration
    echo -e "\n${YELLOW}🌐 Network Configuration${NC}"
    echo -e "${BLUE}Choose IP address assignment method${NC}"
    echo -e "  ${GREEN}1)${NC} DHCP (automatic)"
    echo -e "  ${GREEN}2)${NC} Static IP (manual)"
    
    while true; do
        read -p "Select option [1]: " NET_CHOICE
        NET_CHOICE=${NET_CHOICE:-1}
        
        case $NET_CHOICE in
            1)
                IP_CONFIG="dhcp"
                GATEWAY=""
                echo -e "${GREEN}✓ Using DHCP${NC}"
                break
                ;;
            2)
                echo -e "\n${BLUE}Static IP Configuration${NC}"
                read -p "IP Address/CIDR (e.g., 192.168.1.100/24): " STATIC_IP
                
                # Validate IP format
                if [[ ! $STATIC_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
                    echo -e "${RED}✖ Invalid IP format. Use format: 192.168.1.100/24${NC}"
                    continue
                fi
                
                read -p "Gateway (e.g., 192.168.1.1): " GATEWAY
                
                # Validate gateway format
                if [[ ! $GATEWAY =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                    echo -e "${RED}✖ Invalid gateway format. Use format: 192.168.1.1${NC}"
                    continue
                fi
                
                IP_CONFIG="$STATIC_IP,gw=$GATEWAY"
                echo -e "${GREEN}✓ Static IP configured: $STATIC_IP via $GATEWAY${NC}"
                break
                ;;
            *)
                echo -e "${RED}✖ Invalid choice. Please select 1 or 2${NC}"
                ;;
        esac
    done
    
    # Storage selection
    echo -e "\n${YELLOW}Available Storage:${NC}"
    pvesm status | grep -E '^[^ ]+' | awk 'NR>1 {print "  • " $1}'
    read -p "Storage for container [local-lvm]: " STORAGE
    STORAGE=${STORAGE:-local-lvm}
    
    # Display summary
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Configuration Summary:${NC}"
    echo -e "  Container ID: ${MAGENTA}$CTID${NC}"
    echo -e "  Hostname: ${MAGENTA}$HOSTNAME${NC}"
    echo -e "  Root Password: ${MAGENTA}$([ -n "$ROOT_PASSWORD" ] && echo "Set" || echo "Not Set")${NC}"
    echo -e "  Disk: ${MAGENTA}${DISK_SIZE}GB${NC}"
    echo -e "  Memory: ${MAGENTA}${MEMORY}MB${NC}"
    echo -e "  CPU Cores: ${MAGENTA}$CORES${NC}"
    echo -e "  Network Bridge: ${MAGENTA}$BRIDGE${NC}"
    if [ "$IP_CONFIG" = "dhcp" ]; then
        echo -e "  IP Configuration: ${MAGENTA}DHCP${NC}"
    else
        echo -e "  IP Configuration: ${MAGENTA}Static - $STATIC_IP${NC}"
        echo -e "  Gateway: ${MAGENTA}$GATEWAY${NC}"
    fi
    echo -e "  Storage: ${MAGENTA}$STORAGE${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
    
    read -p "Proceed with installation? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Installation cancelled.${NC}"
        exit 0
    fi
}

# Download Debian template if not exists
function download_template() {
    echo -e "\n${YELLOW}📥 Checking for Debian template...${NC}"
    
    # Update available templates
    echo -e "${YELLOW}Updating template list...${NC}"
    pveam update
    
    # Find Debian 12 standard template from system repo
    TEMPLATE_NAME=$(pveam available | grep "^system" | grep "debian-12-standard" | awk '{print $2}' | head -1)
    
    if [ -z "$TEMPLATE_NAME" ]; then
        echo -e "${YELLOW}Debian 12 not found, trying Debian 13...${NC}"
        TEMPLATE_NAME=$(pveam available | grep "^system" | grep "debian-13-standard" | awk '{print $2}' | head -1)
    fi
    
    if [ -z "$TEMPLATE_NAME" ]; then
        echo -e "${RED}✖ Could not find a suitable Debian template${NC}"
        echo -e "${YELLOW}Available templates:${NC}"
        pveam available | grep "^system" | grep "debian"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Selected template: $TEMPLATE_NAME${NC}"
    
    # Check if already downloaded
    if pveam list local | grep -q "$TEMPLATE_NAME"; then
        echo -e "${GREEN}✓ Template already downloaded${NC}"
        TEMPLATE_PATH="local:vztmpl/$TEMPLATE_NAME"
    else
        echo -e "${YELLOW}Downloading template: $TEMPLATE_NAME${NC}"
        echo -e "${BLUE}This may take a few minutes...${NC}"
        
        # Download from system repository to local storage
        if pveam download local "system:$TEMPLATE_NAME"; then
            echo -e "${GREEN}✓ Template downloaded successfully${NC}"
            TEMPLATE_PATH="local:vztmpl/$TEMPLATE_NAME"
        else
            echo -e "${YELLOW}Trying alternative download method...${NC}"
            
            # Try without 'system:' prefix
            if pveam download local "$TEMPLATE_NAME"; then
                echo -e "${GREEN}✓ Template downloaded successfully${NC}"
                TEMPLATE_PATH="local:vztmpl/$TEMPLATE_NAME"
            else
                echo -e "${RED}✖ Failed to download template${NC}"
                exit 1
            fi
        fi
    fi
}

# Create LXC container
function create_container() {
    echo -e "\n${YELLOW}🔧 Creating LXC container...${NC}"
    
    # Build password argument if provided
    PASSWORD_ARG=""
    if [ -n "${ROOT_PASSWORD:-}" ]; then
        PASSWORD_ARG="--password '$ROOT_PASSWORD'"
    fi
    
    # Create container with appropriate network config
    if eval pct create $CTID $TEMPLATE_PATH \
        --hostname $HOSTNAME \
        --memory $MEMORY \
        --cores $CORES \
        --rootfs $STORAGE:$DISK_SIZE \
        --net0 name=eth0,bridge=$BRIDGE,firewall=1,ip=$IP_CONFIG \
        --features nesting=1 \
        --unprivileged 1 \
        --onboot 1 \
        $PASSWORD_ARG \
        --start 1; then
        
        echo -e "${GREEN}✓ Container created and started${NC}"
    else
        echo -e "${RED}✖ Failed to create container${NC}"
        exit 1
    fi
    
    # Wait for container to fully start
    echo -e "${YELLOW}⏳ Waiting for container to initialize...${NC}"
    sleep 5
    
    # Wait for network to be ready
    local MAX_WAIT=30
    local WAITED=0
    while [ $WAITED -lt $MAX_WAIT ]; do
        if pct exec $CTID -- ip addr show eth0 2>/dev/null | grep -q "inet "; then
            echo -e "${GREEN}✓ Container network is ready${NC}"
            break
        fi
        sleep 2
        WAITED=$((WAITED + 2))
    done
}

# Install application in container
function install_application() {
    echo -e "\n${YELLOW}📦 Installing application in container...${NC}"
    
    # Create installation script
    cat > /tmp/install_app_${CTID}.sh << 'EOFSCRIPT'
#!/bin/bash

set -e

echo "Updating system..."
apt update && apt upgrade -y

echo "Installing prerequisites..."
apt install -y curl git ca-certificates gnupg build-essential python3 jq

echo "Installing Node.js 20 LTS..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"

echo "Cloning application repository..."
cd /opt
git clone GITHUB_REPO invai
cd invai

echo "Installing application dependencies..."
npm install --production

echo "Creating data directory..."
mkdir -p data
chmod 755 data

echo "Creating update script..."
cat > /usr/local/bin/update-inventory << 'UPDATEEOF'
#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╭─────────────────────────────────────────────╮${NC}"
echo -e "${BLUE}│   🔄 Inventory App Update Manager    │${NC}"
echo -e "${BLUE}╰─────────────────────────────────────────────╯${NC}"
echo

cd /opt/invai || exit 1

echo -e "${YELLOW}⏳ Stopping application service...${NC}"
systemctl stop inventory-app

echo -e "${YELLOW}📥 Fetching latest updates from GitHub...${NC}"
git fetch origin

# Get current and remote commit
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse @{u})

if [ $LOCAL = $REMOTE ]; then
    echo -e "${GREEN}✓ Already up to date!${NC}"
    echo -e "${YELLOW}▶️ Starting application service...${NC}"
    systemctl start inventory-app
    exit 0
fi

echo -e "${BLUE}🔽 Pulling latest changes...${NC}"
git pull origin main

echo -e "${YELLOW}📦 Updating dependencies...${NC}"
npm install --production

echo -e "${YELLOW}▶️ Starting application service...${NC}"
systemctl start inventory-app

echo -e "${YELLOW}⏳ Waiting for service to be ready...${NC}"
sleep 3

if systemctl is-active --quiet inventory-app; then
    echo -e "${GREEN}✓ Update completed successfully!${NC}"
    
    # Show current version
    VERSION=$(jq -r '.version // "unknown"' /opt/invai/package.json 2>/dev/null || echo "unknown")
    IP=$(hostname -I | awk '{print $1}')
    echo -e "${GREEN}Version: ${VERSION}${NC}"
    echo -e "${GREEN}Access at: http://${IP}:3000${NC}"
else
    echo -e "${RED}✗ Service failed to start after update!${NC}"
    echo -e "${YELLOW}Check logs: journalctl -u inventory-app -n 50${NC}"
    exit 1
fi
UPDATEEOF

chmod +x /usr/local/bin/update-inventory

# Create alias
echo "alias update='update-inventory'" >> /root/.bashrc

echo "Creating dynamic MOTD..."
# Disable default Debian MOTD scripts
chmod -x /etc/update-motd.d/* 2>/dev/null || true

# Create custom MOTD script
mkdir -p /etc/update-motd.d
cat > /etc/update-motd.d/10-inventory-app << 'MOTDEOF'
#!/bin/bash

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Get app info
VERSION=$(jq -r '.version // "unknown"' /opt/invai/package.json 2>/dev/null || echo "unknown")
IP=$(hostname -I | awk '{print $1}')
PORT="3000"
STATUS=$(systemctl is-active inventory-app 2>/dev/null || echo "inactive")

if [ "$STATUS" = "active" ]; then
    STATUS_TEXT="${GREEN}✓ Running${NC}"
    STATUS_ICON="🟢"
else
    STATUS_TEXT="${YELLOW}✗ Stopped${NC}"
    STATUS_ICON="🔴"
fi

echo -e "${CYAN}"
echo "╭──────────────────────────────────────────────────────────────────────╮"
echo -e "│     ${MAGENTA}📦 Inventory Management System${CYAN}                           │"
echo "╰──────────────────────────────────────────────────────────────────────╯"
echo -e "${NC}"
echo -e "  ${BLUE}Version:${NC}  ${GREEN}v${VERSION}${NC}"
echo -e "  ${BLUE}Status:${NC}   ${STATUS_ICON} ${STATUS_TEXT}"
echo -e "  ${BLUE}IP Addr:${NC}  ${YELLOW}${IP}${NC}"
echo -e "  ${BLUE}Port:${NC}     ${YELLOW}${PORT}${NC}"
echo -e "  ${BLUE}URL:${NC}      ${CYAN}http://${IP}:${PORT}${NC}"
echo
echo -e "  ${MAGENTA}🛠️  Commands:${NC}"
echo -e "    ${GREEN}update${NC}              - Update to latest version"
echo -e "    ${GREEN}systemctl status inventory-app${NC}  - Check service status"
echo -e "    ${GREEN}journalctl -fu inventory-app${NC}    - View live logs"
echo
MOTDEOF

chmod +x /etc/update-motd.d/10-inventory-app

# Clear existing MOTD
echo "" > /etc/motd

echo "Creating systemd service..."
cat > /etc/systemd/system/inventory-app.service << 'EOF'
[Unit]
Description=Inventory Management Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/invai
ExecStart=/usr/bin/node /opt/invai/server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3000
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "Enabling and starting service..."
systemctl daemon-reload
systemctl enable inventory-app.service
systemctl start inventory-app.service

echo "Waiting for service to start..."
sleep 3

if systemctl is-active --quiet inventory-app; then
    echo "✓ Service started successfully"
else
    echo "✗ Service failed to start"
    journalctl -u inventory-app -n 20
    exit 1
fi

echo "Installation complete!"
EOFSCRIPT

    # Replace GitHub repo URL
    sed -i "s|GITHUB_REPO|$GITHUB_REPO|g" /tmp/install_app_${CTID}.sh
    
    # Copy script to container
    pct push $CTID /tmp/install_app_${CTID}.sh /tmp/install_app.sh
    
    # Make executable and run
    pct exec $CTID -- chmod +x /tmp/install_app.sh
    
    echo -e "${BLUE}Running installation inside container (this may take 5-10 minutes)...${NC}"
    if pct exec $CTID -- /tmp/install_app.sh; then
        echo -e "${GREEN}✓ Application installed successfully${NC}"
    else
        echo -e "${RED}✖ Application installation failed${NC}"
        echo -e "${YELLOW}Check logs with: pct exec $CTID -- journalctl -u inventory-app -n 50${NC}"
        exit 1
    fi
    
    # Cleanup
    rm -f /tmp/install_app_${CTID}.sh
    pct exec $CTID -- rm -f /tmp/install_app.sh
}

# Get container IP
function get_container_ip() {
    echo -e "\n${YELLOW}🔍 Getting container IP address...${NC}"
    
    # Wait a bit for network to be ready
    sleep 2
    
    # Try multiple methods to get IP
    CONTAINER_IP=$(pct exec $CTID -- hostname -I | awk '{print $1}' 2>/dev/null || echo "")
    
    if [ -z "$CONTAINER_IP" ]; then
        # Alternative method
        CONTAINER_IP=$(pct exec $CTID -- ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' 2>/dev/null || echo "")
    fi
    
    if [ -z "$CONTAINER_IP" ]; then
        echo -e "${YELLOW}⚠️  Could not automatically detect IP address${NC}"
        echo -e "${BLUE}You can find it by running: pct exec $CTID -- hostname -I${NC}"
    else
        echo -e "${GREEN}✓ Container IP: $CONTAINER_IP${NC}"
    fi
}

# Display completion message
function completion_message() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ Installation Complete!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${MAGENTA}📊 Container Details:${NC}"
    echo -e "  Container ID: ${CYAN}$CTID${NC}"
    echo -e "  Hostname: ${CYAN}$HOSTNAME${NC}"
    
    if [ -n "${ROOT_PASSWORD:-}" ]; then
        echo -e "  Root Password: ${GREEN}Set${NC}"
        echo -e "\n${GREEN}🔐 Login Methods:${NC}"
        echo -e "  From Proxmox: ${CYAN}pct enter $CTID${NC}"
        if [ -n "$CONTAINER_IP" ]; then
            echo -e "  SSH: ${CYAN}ssh root@$CONTAINER_IP${NC}"
        fi
    else
        echo -e "  Root Password: ${YELLOW}Not Set${NC}"
        echo -e "\n${GREEN}🔐 Login Method:${NC}"
        echo -e "  From Proxmox: ${CYAN}pct enter $CTID${NC}"
        echo -e "  Set password: ${CYAN}pct exec $CTID -- passwd${NC}"
    fi
    
    if [ -n "$CONTAINER_IP" ]; then
        echo -e "  IP Address: ${CYAN}$CONTAINER_IP${NC}"
        echo -e "\n${GREEN}🌐 Access your Inventory Management System:${NC}"
        echo -e "  ${BLUE}http://$CONTAINER_IP:$APP_PORT${NC}\n"
    else
        echo -e "\n${YELLOW}Get IP address with: pct exec $CTID -- hostname -I${NC}"
        echo -e "${YELLOW}Then access at: http://[IP]:$APP_PORT${NC}\n"
    fi
    
    echo -e "${MAGENTA}🔄 Update Command:${NC}"
    echo -e "  Inside container, run: ${CYAN}update${NC}"
    echo -e "  This will fetch and install the latest version from GitHub\n"
    
    echo -e "${MAGENTA}🔧 Useful Commands:${NC}"
    echo -e "  Check status: ${CYAN}pct exec $CTID -- systemctl status inventory-app${NC}"
    echo -e "  View logs: ${CYAN}pct exec $CTID -- journalctl -u inventory-app -f${NC}"
    echo -e "  Restart app: ${CYAN}pct exec $CTID -- systemctl restart inventory-app${NC}"
    echo -e "  Update app: ${CYAN}pct exec $CTID -- update-inventory${NC}"
    echo -e "  Enter container: ${CYAN}pct enter $CTID${NC}"
    echo -e "  Stop container: ${CYAN}pct stop $CTID${NC}"
    echo -e "  Start container: ${CYAN}pct start $CTID${NC}\n"
    
    echo -e "${MAGENTA}🔒 Configure Nginx Proxy Manager:${NC}"
    if [ -n "$CONTAINER_IP" ]; then
        echo -e "  Forward to: ${CYAN}$CONTAINER_IP:$APP_PORT${NC}"
    fi
    echo -e "  Enable SSL for external access\n"
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
}

# Error handler
function error_handler() {
    echo -e "\n${RED}✖ An error occurred during installation!${NC}"
    echo -e "${YELLOW}Check the error messages above for details.${NC}"
    
    if pct status $CTID &>/dev/null; then
        echo -e "\n${YELLOW}Container $CTID was created. You can:${NC}"
        echo -e "  Remove it: ${CYAN}pct stop $CTID && pct destroy $CTID${NC}"
        echo -e "  Debug it: ${CYAN}pct enter $CTID${NC}"
    fi
    
    exit 1
}

trap error_handler ERR

# Main installation flow
function main() {
    banner
    check_root
    check_proxmox
    get_user_input
    download_template
    create_container
    install_application
    get_container_ip
    completion_message
}

# Run main function
main