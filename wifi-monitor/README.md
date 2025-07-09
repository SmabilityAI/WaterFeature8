# Industrial-Grade WiFi Connection Monitor

A robust, enterprise-grade WiFi connection monitoring and recovery system designed 
for Raspberry Pi and Linux systems. This solution provides automatic reconnection, 
failover mechanisms, and captive portal integration for uninterrupted connectivity.

## Features

- **Multi-tier Recovery System**: Progressive escalation from simple reconnection 
to captive portal
- **Redundant Internet Checking**: Tests multiple DNS servers (Google, Cloudflare, 
OpenDNS)
- **Intelligent Reconnection**: Attempts to reconnect to saved networks with 
priority ordering
- **Captive Portal Integration**: Automatically launches WiFi Connect when all else 
fails
- **Comprehensive Logging**: Detailed logs for monitoring and debugging
- **Systemd Integration**: Runs as a system service with auto-restart capabilities

## System Requirements

- Linux system with NetworkManager (nmcli)
- WiFi Connect binary (for captive portal functionality)
- Systemd for service management
- Root privileges for installation

## Installation

### Step 1: Download and Setup Script

```bash
# Navigate to your home directory
cd /home/smability

# Backup existing script (if any)
cp smart-wifi-connect.sh smart-wifi-connect.sh.backup 2>/dev/null || true

# Create the industrial WiFi monitor script
nano industrial-wifi-monitor.sh
# Paste the script content and save (Ctrl+X, Y, Enter)

# Make executable
chmod +x industrial-wifi-monitor.sh
```

### Step 2: Install as System Service

```bash
# Create systemd service file
sudo tee /etc/systemd/system/wifi-connect.service << 'EOF'
[Unit]
Description=Industrial WiFi Monitor
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
ExecStart=/home/smability/industrial-wifi-monitor.sh
Restart=always
RestartSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
sudo systemctl daemon-reload
sudo systemctl enable wifi-connect.service
sudo systemctl start wifi-connect.service
```

### Step 3: Verify Installation

```bash
# Check service status
sudo systemctl status wifi-connect.service

# View real-time logs
sudo tail -f /var/log/wifi-monitor.log

# Or view system logs
sudo journalctl -u wifi-connect -f
```

## Configuration

The script includes several configurable parameters at the top:

```bash
CHECK_INTERVAL=10          # Check every 10 seconds
PING_TIMEOUT=3            # Ping timeout in seconds
MAX_RECONNECT_ATTEMPTS=6  # Try reconnecting 6 times
WIFI_CONNECT_DELAY=5      # Wait before starting WiFi Connect
```

To modify these settings:

```bash
sudo nano /home/smability/industrial-wifi-monitor.sh
# Edit the configuration section
# Restart the service
sudo systemctl restart wifi-connect.service
```

## How It Works

### Monitoring Phase
- Continuously monitors internet connectivity every 10 seconds
- Tests multiple DNS servers for redundancy (8.8.8.8, 1.1.1.1, 208.67.222.222)
- Tracks consecutive failures to determine recovery strategy

### Recovery Escalation
1. **First Failure (0-10s)**: Logs the issue and checks WiFi status
2. **Second Failure (10-20s)**: Attempts to reconnect to saved WiFi networks
3. **Third+ Failures (30s+)**: Launches WiFi Connect captive portal

### Reconnection Logic
- Retrieves all saved WiFi connections
- Attempts connection in priority order
- Waits and tests internet after each attempt
- Falls back to captive portal if all attempts fail

## Monitoring and Troubleshooting

### View Logs
```bash
# Real-time monitoring
sudo tail -f /var/log/wifi-monitor.log

# System service logs
sudo journalctl -u wifi-connect -f

# Historical logs
sudo journalctl -u wifi-connect --since "1 hour ago"
```

### Common Commands
```bash
# Restart the service
sudo systemctl restart wifi-connect.service

# Stop the service
sudo systemctl stop wifi-connect.service

# Check service status
sudo systemctl status wifi-connect.service

# Manual script execution (for testing)
sudo /home/smability/industrial-wifi-monitor.sh
```

### Log Messages
- `Industrial WiFi Monitor started` - Service initialization
- `Internet check failed` - Connectivity issue detected
- `Attempting reconnection` - Trying to reconnect to saved networks
- `Starting WiFi Connect captive portal` - Launching captive portal
- `Internet restored` - Connection recovered

## Uninstallation

```bash
# Stop and disable service
sudo systemctl stop wifi-connect.service
sudo systemctl disable wifi-connect.service

# Remove service file
sudo rm /etc/systemd/system/wifi-connect.service

# Remove script
rm /home/smability/industrial-wifi-monitor.sh

# Remove logs
sudo rm /var/log/wifi-monitor.log

# Reload systemd
sudo systemctl daemon-reload
```

## Dependencies

### Required Packages
```bash
sudo apt update
sudo apt install -y network-manager wireless-tools
```

### WiFi Connect Binary
This script requires the WiFi Connect binary to be available at 
`/home/smability/wifi-connect`. Download from 
[balena-io/wifi-connect](https://github.com/balena-io/wifi-connect).

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is open source and available under the MIT License.

## Support

For issues and questions:
- Check the logs first: `sudo tail -f /var/log/wifi-monitor.log`
- Verify service status: `sudo systemctl status wifi-connect.service`
- Open an issue in this repository with relevant log excerpts
