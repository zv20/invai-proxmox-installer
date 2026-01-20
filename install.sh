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
        echo -e "${RED}❌ Error: This script must be run on a Proxmox VE host!${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Running on Proxmox VE $(pveversion | grep -oP 'pve-manager/\K[0-9.]+')
${NC}"
}

# Check if running as root
function check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ This script must be run as root${NC}"
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
            echo -e "${RED}❌ Container $CTID already exists!${NC}"
        else
            break
        fi
    done
    
    # Hostname
    read -p "Hostname [$DEFAULT_HOSTNAME]: " HOSTNAME
    HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}
    
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
    
    # Storage selection
    echo -e "\n${YELLOW}Available Storage:${NC}"
    pvesm status | grep -E '^[^ ]+' | awk '{print "  • " $1}'
    read -p "Storage for container [local-lvm]: " STORAGE
    STORAGE=${STORAGE:-local-lvm}
    
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Configuration Summary:${NC}"
    echo -e "  Container ID: ${MAGENTA}$CTID${NC}"
    echo -e "  Hostname: ${MAGENTA}$HOSTNAME${NC}"
    echo -e "  Disk: ${MAGENTA}${DISK_SIZE}GB${NC}"
    echo -e "  Memory: ${MAGENTA}${MEMORY}MB${NC}"
    echo -e "  CPU Cores: ${MAGENTA}$CORES${NC}"
    echo -e "  Network: ${MAGENTA}$BRIDGE${NC}"
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
    echo -e "\n${YELLOW}📥 Checking for Debian 12 template...${NC}"
    
    TEMPLATE="debian-12-standard_12.7-1_amd64.tar.zst"
    
    if ! pveam list local | grep -q "$TEMPLATE"; then
        echo -e "${YELLOW}Downloading Debian 12 template...${NC}"
        pveam download local $TEMPLATE
        echo -e "${GREEN}✓ Template downloaded${NC}"
    else
        echo -e "${GREEN}✓ Template already available${NC}"
    fi
}

# Create LXC container
function create_container() {
    echo -e "\n${YELLOW}🔧 Creating LXC container...${NC}"
    
    # Get template path
    TEMPLATE_PATH=$(pveam path local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst 2>/dev/null || 
                    pveam path local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst 2>/dev/null || 
                    echo "")
    
    if [ -z "$TEMPLATE_PATH" ]; then
        echo -e "${RED}❌ Debian template not found!${NC}"
        exit 1
    fi
    
    # Create container
    pct create $CTID $TEMPLATE_PATH \
        --hostname $HOSTNAME \
        --memory $MEMORY \
        --cores $CORES \
        --rootfs $STORAGE:$DISK_SIZE \
        --net0 name=eth0,bridge=$BRIDGE,firewall=1,ip=dhcp \
        --features nesting=1 \
        --unprivileged 1 \
        --onboot 1 \
        --start 1
    
    echo -e "${GREEN}✓ Container created and started${NC}"
    
    # Wait for container to fully start
    echo -e "${YELLOW}⏳ Waiting for container to initialize...${NC}"
    sleep 5
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
apt install -y curl git ca-certificates gnupg

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
    pct exec $CTID -- /tmp/install_app.sh
    
    # Cleanup
    rm /tmp/install_app_${CTID}.sh
    pct exec $CTID -- rm /tmp/install_app.sh
    
    echo -e "${GREEN}✓ Application installed successfully${NC}"
}

# Get container IP
function get_container_ip() {
    echo -e "\n${YELLOW}🔍 Getting container IP address...${NC}"
    
    # Wait a bit for network to be ready
    sleep 2
    
    # Try multiple methods to get IP
    CONTAINER_IP=$(pct exec $CTID -- hostname -I | awk '{print $1}' || echo "")
    
    if [ -z "$CONTAINER_IP" ]; then
        # Alternative method
        CONTAINER_IP=$(pct exec $CTID -- ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "")
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
    
    if [ -n "$CONTAINER_IP" ]; then
        echo -e "  IP Address: ${CYAN}$CONTAINER_IP${NC}"
        echo -e "\n${GREEN}🌐 Access your Inventory Management System:${NC}"
        echo -e "  ${BLUE}http://$CONTAINER_IP:$APP_PORT${NC}\n"
    else
        echo -e "\n${YELLOW}Get IP address with: pct exec $CTID -- hostname -I${NC}"
        echo -e "${YELLOW}Then access at: http://[IP]:$APP_PORT${NC}\n"
    fi
    
    echo -e "${MAGENTA}🔧 Useful Commands:${NC}"
    echo -e "  Check status: ${CYAN}pct exec $CTID -- systemctl status inventory-app${NC}"
    echo -e "  View logs: ${CYAN}pct exec $CTID -- journalctl -u inventory-app -f${NC}"
    echo -e "  Restart app: ${CYAN}pct exec $CTID -- systemctl restart inventory-app${NC}"
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
    echo -e "\n${RED}❌ An error occurred during installation!${NC}"
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