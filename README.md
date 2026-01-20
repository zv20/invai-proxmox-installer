# 📦 Inventory Management System - Proxmox Installer

One-click automated installer for deploying the Inventory Management System on Proxmox VE. This script creates an LXC container and installs everything automatically.

## ✨ Features

- 🚀 **Fully Automated** - One command does everything
- 📦 **LXC Container Creation** - Automatically creates and configures container
- 🔧 **Complete Installation** - Node.js, application, and systemd service
- 🌐 **Network Ready** - DHCP configuration with auto-detected IP
- 🔄 **Auto-start on Boot** - Container and app start automatically
- 💾 **Persistent Storage** - SQLite database with proper data directory
- 📊 **Interactive Setup** - Guided configuration with sensible defaults
- ⬆️ **Easy Updates** - One-command updates from GitHub

## 🎯 What This Script Does

1. ✅ Checks Proxmox environment and permissions
2. ✅ Prompts for container configuration (with defaults)
3. ✅ Downloads Debian 12 template (if needed)
4. ✅ Creates LXC container with specified resources
5. ✅ Installs Node.js 20 LTS
6. ✅ Clones and installs the inventory application
7. ✅ Creates systemd service for auto-start
8. ✅ Starts the application
9. ✅ Shows you the URL to access your app

## 🚀 Quick Start

### Run on Proxmox Host

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/zv20/invai-proxmox-installer/main/install.sh)"
```

### Or Download and Run

```bash
wget https://raw.githubusercontent.com/zv20/invai-proxmox-installer/main/install.sh
chmod +x install.sh
./install.sh
```

## 📋 Prerequisites

- Proxmox VE 7.0 or newer
- Root access to Proxmox host
- Internet connection for downloading packages
- Available storage for LXC container

## ⚙️ Configuration Options

The script will prompt you for:

| Option | Default | Description |
|--------|---------|-------------|
| Container ID | 200 | Unique CT ID for the container |
| Hostname | inventory-app | Container hostname |
| Disk Size | 4 GB | Root filesystem size |
| Memory | 512 MB | RAM allocation |
| CPU Cores | 1 | Number of CPU cores |
| Network Bridge | vmbr0 | Network bridge to use |
| Storage | local-lvm | Storage backend for container |

**Just press Enter to accept defaults!**

## 🎬 Installation Demo

```
═══════════════════════════════════════════════════════════
    📦 Inventory Management System - Proxmox Installer
═══════════════════════════════════════════════════════════

✓ Running on Proxmox VE 8.1.3
✓ Running with root privileges

📝 Container Configuration
Press Enter to use default values shown in [brackets]

Container ID [200]: 
Hostname [inventory-app]: 
Disk Size in GB [4]: 
Memory in MB [512]: 
CPU Cores [1]: 
Network Bridge [vmbr0]: 

... (automatic installation) ...

✅ Installation Complete!

🌐 Access your Inventory Management System:
  http://192.168.1.100:3000
```

## ⬆️ Updating Your Application

Two methods to update your installation when you push changes to GitHub:

### Method 1: Update from Proxmox Host (Recommended)

```bash
# Download and run update script
wget https://raw.githubusercontent.com/zv20/invai-proxmox-installer/main/update-from-host.sh
chmod +x update-from-host.sh
./update-from-host.sh 600  # Replace 600 with your container ID
```

Or one-liner:
```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/zv20/invai-proxmox-installer/main/update-from-host.sh)" -- 600
```

### Method 2: Update from Inside Container

```bash
# Enter the container
pct enter 600

# Download and run update script
wget https://raw.githubusercontent.com/zv20/invai-proxmox-installer/main/update.sh
chmod +x update.sh
./update.sh
```

### What the Update Does

1. ✓ Shows current version and checks for updates
2. ✓ Warns if there are uncommitted local changes
3. ✓ Displays changelog of new commits
4. ✓ Stops the service gracefully
5. ✓ Pulls latest code from GitHub
6. ✓ Updates dependencies (npm install)
7. ✓ Restarts the service
8. ✓ Verifies successful startup
9. ✓ Shows new version and status

### Update Output Example

```
═══════════════════════════════════════════════════════════
    📦 Inventory Management System - Update
═══════════════════════════════════════════════════════════

📋 Current Status
  Branch: main
  Commit: abc1234
  Service: active

📥 Fetching latest changes from GitHub...
📦 New changes available
Changes since current version:
xyz5678 Add new feature
abc9012 Fix bug

🛑 Stopping service...
✓ Service stopped

⬇️  Pulling latest code...
✓ Code updated

📦 Checking for dependency updates...
✓ Dependencies updated

🔄 Starting service...
✓ Service started successfully

═══════════════════════════════════════════════════════════
✅ Update Complete!
═══════════════════════════════════════════════════════════

📊 New Status
  Branch: main
  Commit: xyz5678
  Message: Add new feature
  Service: active

💡 Useful commands:
  View logs: journalctl -u inventory-app -f
  Restart: systemctl restart inventory-app
  Status: systemctl status inventory-app
```

## 🌐 Accessing Your App

After installation completes:

### Local Network Access
```
http://[CONTAINER-IP]:3000
```

The installer will display the exact IP address.

### Configure Nginx Proxy Manager

For external access with SSL:

1. Open Nginx Proxy Manager
2. Add Proxy Host:
   - Domain: `inventory.yourdomain.com`
   - Forward to: `[CONTAINER-IP]:3000`
   - Enable SSL (Let's Encrypt)
3. Access via: `https://inventory.yourdomain.com`

## 🔧 Managing Your Installation

### Container Management

```bash
# Enter container
pct enter 600

# Stop container
pct stop 600

# Start container
pct start 600

# Restart container
pct restart 600

# View container config
pct config 600
```

### Application Management

```bash
# Check service status
pct exec 600 -- systemctl status inventory-app

# View logs (live)
pct exec 600 -- journalctl -u inventory-app -f

# Restart application
pct exec 600 -- systemctl restart inventory-app

# Stop application
pct exec 600 -- systemctl stop inventory-app
```

### Access Application Files

```bash
# Enter container and navigate to app
pct enter 600
cd /opt/invai

# View logs
journalctl -u inventory-app -n 50

# Manual update (alternative to update script)
git pull
npm install
systemctl restart inventory-app
```

## 🗑️ Uninstallation

To completely remove the installation:

```bash
# Stop and destroy container
pct stop 600
pct destroy 600
```

## 🔍 Troubleshooting

### Container Won't Start

```bash
# Check container status
pct status 600

# View container logs
pct enter 600
journalctl -xe
```

### Application Not Responding

```bash
# Check application logs
pct exec 600 -- journalctl -u inventory-app -n 50

# Check if service is running
pct exec 600 -- systemctl status inventory-app

# Restart application
pct exec 600 -- systemctl restart inventory-app
```

### Can't Access from Browser

1. **Get container IP:**
   ```bash
   pct exec 600 -- hostname -I
   ```

2. **Check if port 3000 is listening:**
   ```bash
   pct exec 600 -- ss -tlnp | grep 3000
   ```

3. **Check firewall:**
   ```bash
   # On Proxmox host
   iptables -L -n | grep 3000
   ```

### Database Issues

```bash
# Enter container
pct enter 600

# Check database location
ls -la /opt/invai/inventory.db

# Backup database
cp /opt/invai/inventory.db /opt/invai/inventory.db.backup
```

### Update Failed

```bash
# View update logs
pct exec 600 -- journalctl -u inventory-app -n 100

# Check git status
pct enter 600
cd /opt/invai
git status

# Force update (discards local changes)
git reset --hard HEAD
git pull
npm install
systemctl restart inventory-app
```

## 📊 Resource Usage

Typical resource consumption:

- **Disk**: ~500 MB (with OS and app)
- **Memory**: ~100-150 MB (idle)
- **CPU**: Minimal (idle), spikes during use

## 🔐 Security Recommendations

1. **Use Nginx Proxy Manager** for SSL termination
2. **Enable firewall rules** to restrict access
3. **Regular updates:**
   ```bash
   pct exec 600 -- apt update && apt upgrade -y
   ```
4. **Backup database regularly:**
   ```bash
   pct exec 600 -- cp /opt/invai/inventory.db /root/backup/
   ```

## 🆘 Support

If you encounter issues:

1. Check the troubleshooting section above
2. View application logs: `pct exec 600 -- journalctl -u inventory-app -f`
3. Create an issue on GitHub with:
   - Proxmox version
   - Error messages
   - Log output

## 📝 Application Repository

The inventory application source code: [zv20/invai](https://github.com/zv20/invai)

## 🙏 Credits

Inspired by [tteck's Proxmox Helper Scripts](https://github.com/tteck/Proxmox) and [Community Scripts](https://github.com/community-scripts/ProxmoxVE)

## 📄 License

MIT License - Feel free to use and modify!

---

**Made with ❤️ for Proxmox homelab enthusiasts**