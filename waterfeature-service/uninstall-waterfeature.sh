#!/bin/bash

# Water Feature Controller Service Uninstall Script
# Run with: sudo bash uninstall-waterfeature.sh

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
        print_status "Please run: sudo bash uninstall-waterfeature.sh"
        exit 1
    fi
}

# Stop and disable service
stop_service() {
    print_status "Stopping Water Feature Controller service..."
    
    # Stop service if running
    if systemctl is-active --quiet waterfeature.service; then
        systemctl stop waterfeature.service
        print_status "Service stopped"
    else
        print_warning "Service was not running"
    fi
    
    # Disable service if enabled
    if systemctl is-enabled --quiet waterfeature.service; then
        systemctl disable waterfeature.service
        print_status "Service disabled"
    else
        print_warning "Service was not enabled"
    fi
}

# Remove service file
remove_service_file() {
    print_status "Removing systemd service file..."
    
    if [ -f "/etc/systemd/system/waterfeature.service" ]; then
        rm -f /etc/systemd/system/waterfeature.service
        print_status "Service file removed"
    else
        print_warning "Service file not found"
    fi
}

# Clean up systemd
cleanup_systemd() {
    print_status "Cleaning up systemd..."
    
    # Reload systemd daemon
    systemctl daemon-reload
    
    # Reset failed services
    systemctl reset-failed 2>/dev/null || true
    
    print_status "Systemd cleanup complete"
}

# Remove Python dependencies (optional)
remove_dependencies() {
    print_status "Python dependencies cleanup..."
    
    echo
    read -p "Remove Python dependencies (boto3, AWSIoTPythonSDK)? This may affect 
other applications. (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Removing Python dependencies..."
        sudo -u smability pip3 uninstall -y boto3 AWSIoTPythonSDK 2>/dev/null || 
true
        print_status "Python dependencies removed"
    else
        print_status "Python dependencies kept"
    fi
}

# Remove application files (optional)
remove_application() {
    print_status "Application files cleanup..."
    
    if [ -d "/home/smability/WaterFeature8" ]; then
        echo
        read -p "Remove WaterFeature8 application directory? This will delete all 
application files. (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Create backup first
            BACKUP_DIR="/home/smability/backups/waterfeature_$(date 
+%Y%m%d_%H%M%S)"
            mkdir -p "$BACKUP_DIR"
            cp -r /home/smability/WaterFeature8 "$BACKUP_DIR/"
            print_status "Application backed up to: $BACKUP_DIR"
            
            # Remove application directory
            rm -rf /home/smability/WaterFeature8
            print_status "Application directory removed"
        else
            print_status "Application directory kept"
        fi
    else
        print_warning "Application directory not found"
    fi
}

# Remove backups (optional)
remove_backups() {
    print_status "Backup cleanup..."
    
    if [ -d "/home/smability/backups" ]; then
        echo
        read -p "Remove backup directory? This will delete all service backups. 
(y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf /home/smability/backups
            print_status "Backup directory removed"
        else
            print_status "Backup directory kept"
        fi
    else
        print_warning "Backup directory not found"
    fi
}

# Verify uninstallation
verify_uninstall() {
    print_status "Verifying uninstallation..."
    
    local issues=0
    
    # Check service file
    if [ -f "/etc/systemd/system/waterfeature.service" ]; then
        print_warning "✗ Service file still exists"
        ((issues++))
    else
        print_status "✓ Service file removed"
    fi
    
    # Check if service is still running
    if systemctl is-active --quiet waterfeature.service 2>/dev/null; then
        print_warning "✗ Service is still running"
        ((issues++))
    else
        print_status "✓ Service is stopped"
    fi
    
    # Check if service is still enabled
    if systemctl is-enabled --quiet waterfeature.service 2>/dev/null; then
        print_warning "✗ Service is still enabled"
        ((issues++))
    else
        print_status "✓ Service is disabled"
    fi
    
    # Check if service exists in systemd
    if systemctl list-unit-files | grep -q "waterfeature.service"; then
        print_warning "✗ Service still exists in systemd"
        ((issues++))
    else
        print_status "✓ Service removed from systemd"
    fi
    
    if [ $issues -eq 0 ]; then
        print_status "✓ Uninstallation verification successful"
    else
        print_warning "⚠ $issues issues found during verification"
    fi
}

# Show remaining files
show_remaining() {
    print_status "Files that may remain:"
    
    if [ -d "/home/smability/WaterFeature8" ]; then
        echo "  - /home/smability/WaterFeature8/ (application directory)"
    fi
    
    if [ -d "/home/smability/backups" ]; then
        echo "  - /home/smability/backups/ (backup directory)"
    fi
    
    # Check for Python packages
    if sudo -u smability pip3 list | grep -q "boto3\|AWSIoTPythonSDK"; then
        echo "  - Python packages (boto3, AWSIoTPythonSDK)"
    fi
    
    # Check for AWS IoT certificates
    if find /home/smability -name "*.pem" -o -name "*.crt" -o -name "*.key" 
2>/dev/null | grep -q .; then
        echo "  - AWS IoT certificates and keys"
    fi
    
    echo
    print_status "These files were kept and can be manually removed if no longer 
needed."
}

# Main uninstall function
main() {
    print_status "Starting Water Feature Controller service uninstallation..."
    echo
    
    check_root
    stop_service
    remove_service_file
    cleanup_systemd
    remove_dependencies
    remove_application
    remove_backups
    verify_uninstall
    
    echo
    print_status "Uninstallation complete!"
    echo
    show_remaining
    
    print_status "The Water Feature Controller service has been removed."
}

# Handle script interruption
cleanup() {
    echo
    print_warning "Uninstallation interrupted"
    exit 1
}

trap cleanup SIGINT SIGTERM

# Run main function
main "$@"
