#!/bin/bash

# Water Feature Controller Service Installation Script
# Run with: sudo bash install-waterfeature.sh

set -e

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

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script needs to be run with sudo privileges"
        print_status "Please run: sudo bash install-waterfeature.sh"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Python 3 is installed
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is required but not installed"
        print_status "Installing Python 3..."
        apt update && apt install -y python3 python3-pip
    fi
    
    # Check if pip3 is available
    if ! command -v pip3 &> /dev/null; then
        print_status "Installing pip3..."
        apt update && apt install -y python3-pip
    fi
    
    # Check if smability user exists
    if ! id "smability" &>/dev/null; then
        print_error "User 'smability' does not exist"
        print_status "Please create the user first: sudo useradd -m smability"
        exit 1
    fi
    
    # Check if WFaws.py exists
    if [ ! -f "/home/smability/WaterFeature8/WFaws.py" ]; then
        print_error "WFaws.py not found at /home/smability/WaterFeature8/WFaws.py"
        print_status "Please ensure the Water Feature Python script is in the 
correct location"
        exit 1
    fi
    
    print_status "Prerequisites check complete"
}

# Install Python dependencies
install_dependencies() {
    print_status "Installing Python dependencies..."
    
    # Change to the working directory
    cd /home/smability/WaterFeature8
    
    # Install common AWS IoT dependencies
    sudo -u smability pip3 install boto3 AWSIoTPythonSDK
    
    # Install from requirements.txt if it exists
    if [ -f "requirements.txt" ]; then
        print_status "Installing from requirements.txt..."
        sudo -u smability pip3 install -r requirements.txt
    else
        print_warning "requirements.txt not found, skipping"
    fi
    
    print_status "Dependencies installed"
}

# Create backup of existing service
backup_existing() {
    print_status "Backing up existing service..."
    
    BACKUP_DIR="/home/smability/backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    if [ -f "/etc/systemd/system/waterfeature.service" ]; then
        cp "/etc/systemd/system/waterfeature.service" "$BACKUP_DIR/"
        print_status "Backed up existing service file"
    fi
    
    print_status "Backup complete"
}

# Create systemd service file
create_service() {
    print_status "Creating systemd service file..."
    
    cat > /etc/systemd/system/waterfeature.service << 'EOF'
[Unit]
Description=Water Feature Controller AWS IoT
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=10
User=smability
ExecStart=/usr/bin/python3 /home/smability/WaterFeature8/WFaws.py
WorkingDirectory=/home/smability/WaterFeature8
ExecStartPre=/bin/sleep 30

[Install]
WantedBy=multi-user.target
EOF

    print_status "Service file created"
}

# Set proper permissions
set_permissions() {
    print_status "Setting proper permissions..."
    
    # Ensure smability owns the WaterFeature8 directory
    chown -R smability:smability /home/smability/WaterFeature8
    
    # Make the Python script executable
    chmod +x /home/smability/WaterFeature8/WFaws.py
    
    print_status "Permissions set"
}

# Enable and start service
start_service() {
    print_status "Starting Water Feature Controller service..."
    
    # Stop existing service if running
    systemctl stop waterfeature.service 2>/dev/null || true
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable service to start on boot
    systemctl enable waterfeature.service
    
    # Start the service
    systemctl start waterfeature.service
    
    print_status "Service started and enabled"
}

# Test the installation
test_installation() {
    print_status "Testing installation..."
    
    # Wait a moment for service to start
    sleep 5
    
    # Check service status
    if systemctl is-active --quiet waterfeature.service; then
        print_status "✓ Service is running"
    else
        print_warning "✗ Service is not running"
        print_status "Check status with: sudo systemctl status 
waterfeature.service"
        return 1
    fi
    
    # Check if service is enabled
    if systemctl is-enabled --quiet waterfeature.service; then
        print_status "✓ Service is enabled for boot"
    else
        print_warning "✗ Service is not enabled for boot"
    fi
    
    # Check recent logs for errors
    if journalctl -u waterfeature.service --since "1 minute ago" -q --no-pager | 
grep -i error; then
        print_warning "✗ Errors found in recent logs"
        print_status "Check logs with: sudo journalctl -u waterfeature.service -f"
    else
        print_status "✓ No recent errors in logs"
    fi
    
    print_status "Installation test complete"
}

# Display post-installation information
show_info() {
    print_status "Installation complete!"
    echo
    print_status "Service Management Commands:"
    echo "  Start service:    sudo systemctl start waterfeature.service"
    echo "  Stop service:     sudo systemctl stop waterfeature.service"
    echo "  Restart service:  sudo systemctl restart waterfeature.service"
    echo "  Service status:   sudo systemctl status waterfeature.service"
    echo "  View logs:        sudo journalctl -u waterfeature.service -f"
    echo "  Enable on boot:   sudo systemctl enable waterfeature.service"
    echo "  Disable on boot:  sudo systemctl disable waterfeature.service"
    echo
    print_status "The Water Feature Controller is now running and will start 
automatically on boot."
    echo
    print_status "To monitor the service:"
    echo "  sudo journalctl -u waterfeature.service -f"
    echo
    print_status "To check AWS IoT connectivity, review the application logs."
}

# Main installation function
main() {
    print_status "Starting Water Feature Controller service installation..."
    
    check_root
    check_prerequisites
    install_dependencies
    backup_existing
    create_service
    set_permissions
    start_service
    test_installation
    show_info
}

# Handle script interruption
cleanup() {
    echo
    print_warning "Installation interrupted"
    exit 1
}

trap cleanup SIGINT SIGTERM

# Run main function
main "$@"
