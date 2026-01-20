#!/usr/bin/env bash

# Inventory Management System - Host Update Script
# Run this from Proxmox host to update the container

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

CTID="${1:-600}"

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}    📦 Update Container $CTID${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"

# Check if running on Proxmox
if ! command -v pveversion &> /dev/null; then
    echo -e "${RED}✖ This script must be run on a Proxmox VE host${NC}"
    exit 1
fi

# Check if container exists
if ! pct status $CTID &>/dev/null; then
    echo -e "${RED}✖ Container $CTID does not exist${NC}"
    exit 1
fi

# Check if container is running
if ! pct status $CTID | grep -q "running"; then
    echo -e "${RED}✖ Container $CTID is not running${NC}"
    exit 1
fi

echo -e "${YELLOW}📥 Downloading update script...${NC}"
UPDATE_SCRIPT_URL="https://raw.githubusercontent.com/zv20/invai-proxmox-installer/main/update.sh"

if wget -q --spider "$UPDATE_SCRIPT_URL"; then
    pct exec $CTID -- bash -c "wget -qO /tmp/update.sh $UPDATE_SCRIPT_URL && chmod +x /tmp/update.sh"
    echo -e "${GREEN}✓ Update script downloaded${NC}\n"
else
    echo -e "${RED}✖ Failed to download update script${NC}"
    exit 1
fi

echo -e "${YELLOW}🚀 Running update inside container $CTID...${NC}\n"
echo -e "${CYAN}───────────────────────────────────────────────────────────${NC}\n"

pct exec $CTID -- /tmp/update.sh

echo -e "\n${CYAN}───────────────────────────────────────────────────────────${NC}"

echo -e "${YELLOW}Cleaning up...${NC}"
pct exec $CTID -- rm -f /tmp/update.sh
echo -e "${GREEN}✓ Cleanup complete${NC}\n"