#!/bin/bash

# Industrial WiFi Monitor Installation Script
# Run with: bash install.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root for some operations
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script needs to be run with sudo privileges"
        print_status "Please run: sudo bash install.sh"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    print_status "Checking dependencies..."
    
    # Check for nmcli
    if ! command -v nmcli &> /dev/null; then
        print_error "NetworkManager (nmcli) is required but not installed"
        print_status "Installing NetworkManager..."
        apt update && apt install -y network-manager
    fi
    
    # Check for systemctl
    if ! command -v systemctl &> /dev/null; then
        print_error "systemd is required but not available"
        exit 1
    fi
    
    print_status "Dependencies check complete"
}

# Backup existing files
backup_existing() {
    print_status "Backing up existing files..."
    
    BACKUP_DIR="/home/smability/backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup existing scripts
    if [ -f "/home/smability/smart-wifi-connect.sh" ]; then
        cp "/home/smability/smart-wifi-connect.sh" "$BACKUP_DIR/"
        print_status "Backed up smart-wifi-connect.sh"
    fi
    
    if [ -f "/home/smability/industrial-wifi-monitor.sh" ]; then
        cp "/home/smability/industrial-wifi-monitor.sh" "$BACKUP_DIR/"
        print_status "Backed up existing industrial-wifi-monitor.sh"
    fi
    
    # Backup existing service file
    if [ -f "/etc/systemd/system/wifi-connect.service" ]; then
        cp "/etc/systemd/system/wifi-connect.service" "$BACKUP_DIR/"
        print_status "Backed up existing service file"
    fi
    
    print_status "Backups saved to: $BACKUP_DIR"
}

# Install the script
install_script() {
    print_status "Installing Industrial WiFi Monitor script..."
    
    # Check if script file exists in current directory
    if [ ! -f "industrial-wifi-monitor.sh" ]; then
        print_error "industrial-wifi-monitor.sh not found in current directory"
        print_status "Please ensure the script file is in the same directory as 
this installer"
        exit 1
    fi
    
    # Copy script to destination
    cp "industrial-wifi-monitor.sh" "/home/smability/"
    chown smability:smability "/home/smability/industrial-wifi-monitor.sh"
    chmod +x "/home/smability/industrial-wifi-monitor.sh"
    
    print_status "Script installed successfully"
}

# Create systemd service
create_service() {
    print_status "Creating systemd service..."
    
    cat > /etc/systemd/system/wifi-connect.service << 'EOF'
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

    print_status "Service file created"
}

# Setup logging
setup_logging() {
    print_status "Setting up logging..."
    
    # Create log file with proper permissions
    touch /var/log/wifi-monitor.log
    chmod 666 /var/log/wifi-monitor.log
    
    # Setup log rotation
    cat > /etc/logrotate.d/wifi-monitor << 'EOF'
/var/log/wifi-monitor.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 666 root root
}
EOF

    print_status "Logging configured"
}

# Start and enable service
start_service() {
    print_status "Starting Industrial WiFi Monitor service..."
    
    # Stop existing service if running
    systemctl stop wifi-connect.service 2>/dev/null || true
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable and start service
    systemctl enable wifi-connect.service
    systemctl start wifi-connect.service
    
    print_status "Service started and enabled"
}

# Verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    # Check service status
    if systemctl is-active --quiet wifi-connect.service; then
        print_status "✓ Service is running"
    else
        print_warning "✗ Service is not running"
        print_status "Check status with: sudo systemctl status 
wifi-connect.service"
    fi
    
    # Check if script is executable
    if [ -x "/home/smability/industrial-wifi-monitor.sh" ]; then
        print_status "✓ Script is executable"
    else
        print_warning "✗ Script is not executable"
    fi
    
    # Check log file
    if [ -f "/var/log/wifi-monitor.log" ]; then
        print_status "✓ Log file exists"
    else
        print_warning "✗ Log file not found"
    fi
    
    print_status "Installation verification complete"
}

# Main installation function
main() {
    print_status "Starting Industrial WiFi Monitor installation..."
    
    check_root
    check_dependencies
    backup_existing
    install_script
    create_service
    setup_logging
    start_service
    verify_installation
    
    print_status "Installation complete!"
    echo
    print_status "Useful commands:"
    echo "  View logs: sudo tail -f /var/log/wifi-monitor.log"
    echo "  Service status: sudo systemctl status wifi-connect.service"
    echo "  Restart service: sudo systemctl restart wifi-connect.service"
    echo "  Stop service: sudo systemctl stop wifi-connect.service"
    echo
    print_status "The monitor is now running and will automatically start on boot."
}

# Run main function
main "$@"
