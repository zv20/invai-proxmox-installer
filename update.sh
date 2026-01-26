#!/usr/bin/env bash

# Inventory Management System - Update Script
# Run this inside the container to update the application

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

APP_DIR="/opt/invai"
SERVICE_NAME="inventory-app"

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}    📦 Inventory Management System - Update${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}✖ This script must be run as root${NC}"
    exit 1
fi

# Check if app directory exists
if [ ! -d "$APP_DIR" ]; then
    echo -e "${RED}✖ Application directory not found: $APP_DIR${NC}"
    exit 1
fi

cd "$APP_DIR"

# Check if .env file exists
if [ ! -f "$APP_DIR/.env" ]; then
    echo -e "${YELLOW}⚠️  Warning: .env file not found${NC}"
    echo -e "${BLUE}The application may require environment variables like JWT_SECRET${NC}"
    echo -e "${BLUE}To generate a new .env file:${NC}"
    echo -e "  ${CYAN}cd $APP_DIR${NC}"
    echo -e "  ${CYAN}node -e \"console.log('JWT_SECRET=' + require('crypto').randomBytes(64).toString('hex'))\" > .env${NC}"
    echo -e "  ${CYAN}echo 'NODE_ENV=production' >> .env${NC}"
    echo -e "  ${CYAN}echo 'PORT=3000' >> .env${NC}"
    echo -e "  ${CYAN}chmod 600 .env${NC}\n"
fi

echo -e "${YELLOW}📋 Current Status${NC}"
echo -e "  Branch: ${CYAN}$(git branch --show-current)${NC}"
echo -e "  Commit: ${CYAN}$(git rev-parse --short HEAD)${NC}"
echo -e "  Service: ${CYAN}$(systemctl is-active $SERVICE_NAME)${NC}\n"

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}⚠️  Warning: You have uncommitted changes${NC}"
    git status --short
    echo
    read -p "Continue with update? This will discard local changes (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Update cancelled.${NC}"
        exit 0
    fi
    echo -e "${YELLOW}Discarding local changes...${NC}"
    git reset --hard HEAD
fi

echo -e "${YELLOW}📥 Fetching latest changes from GitHub...${NC}"
git fetch origin

LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse @{u})

if [ "$LOCAL" = "$REMOTE" ]; then
    echo -e "${GREEN}✓ Already up to date!${NC}"
    echo -e "\n${CYAN}No update needed. Exiting.${NC}\n"
    exit 0
fi

echo -e "${YELLOW}📦 New changes available${NC}"
echo -e "${BLUE}Changes since current version:${NC}"
git log --oneline HEAD..@{u} | head -10
echo

echo -e "${YELLOW}🛁 Stopping service...${NC}"
systemctl stop $SERVICE_NAME
echo -e "${GREEN}✓ Service stopped${NC}\n"

echo -e "${YELLOW}⬇️  Pulling latest code...${NC}"
git pull origin $(git branch --show-current)
echo -e "${GREEN}✓ Code updated${NC}\n"

echo -e "${YELLOW}📦 Checking for dependency updates...${NC}"
if npm install --production; then
    echo -e "${GREEN}✓ Dependencies updated${NC}\n"
else
    echo -e "${RED}✖ Dependency update failed${NC}"
    echo -e "${YELLOW}Attempting to start service anyway...${NC}\n"
fi

echo -e "${YELLOW}🔄 Starting service...${NC}"
systemctl start $SERVICE_NAME
sleep 3

if systemctl is-active --quiet $SERVICE_NAME; then
    echo -e "${GREEN}✓ Service started successfully${NC}\n"
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ Update Complete!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${MAGENTA}📊 New Status${NC}"
    echo -e "  Branch: ${CYAN}$(git branch --show-current)${NC}"
    echo -e "  Commit: ${CYAN}$(git rev-parse --short HEAD)${NC}"
    echo -e "  Message: ${CYAN}$(git log -1 --pretty=%B | head -1)${NC}"
    echo -e "  Service: ${GREEN}$(systemctl is-active $SERVICE_NAME)${NC}\n"
    
    # Get IP address
    IP=$(hostname -I | awk '{print $1}')
    if [ -n "$IP" ]; then
        echo -e "${GREEN}🌐 Application Access:${NC}"
        echo -e "  URL: ${CYAN}http://${IP}:3000${NC}\n"
    fi
    
    echo -e "${BLUE}💡 Useful commands:${NC}"
    echo -e "  View logs: ${CYAN}journalctl -u $SERVICE_NAME -f${NC}"
    echo -e "  Restart: ${CYAN}systemctl restart $SERVICE_NAME${NC}"
    echo -e "  Status: ${CYAN}systemctl status $SERVICE_NAME${NC}\n"
else
    echo -e "${RED}✖ Service failed to start${NC}"
    echo -e "${YELLOW}Viewing last 30 log lines:${NC}\n"
    journalctl -u $SERVICE_NAME -n 30 --no-pager
    echo -e "\n${YELLOW}Check if .env file exists and contains required variables:${NC}"
    echo -e "  ${CYAN}cat $APP_DIR/.env${NC}\n"
    exit 1
fi