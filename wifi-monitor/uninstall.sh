#!/bin/bash

# Industrial WiFi Monitor Uninstall Script
# Run with: sudo bash uninstall.sh

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
        print_status "Please run: sudo bash uninstall.sh"
        exit 1
    fi
}

# Stop and disable service
stop_service() {
    print_status "Stopping Industrial WiFi Monitor service..."
    
    # Stop service if running
    if systemctl is-active --quiet wifi-connect.service; then
        systemctl stop wifi-connect.service
        print_status "Service stopped"
    else
        print_warning "Service was not running"
    fi
    
    # Disable service if enabled
    if systemctl is-enabled --quiet wifi-connect.service; then
        systemctl disable wifi-connect.service
        print_status "Service disabled"
    else
        print_warning "Service was not enabled"
    fi
}

# Remove service file
remove_service_file() {
    print_status "Removing systemd service file..."
    
    if [ -f "/etc/systemd/system/wifi-connect.service" ]; then
        rm -f /etc/systemd/system/wifi-connect.service
        print_status "Service file removed"
    else
        print_warning "Service file not found"
    fi
}

# Remove script file
remove_script() {
    print_status "Removing script file..."
    
    if [ -f "/home/smability/industrial-wifi-monitor.sh" ]; then
        rm -f /home/smability/industrial-wifi-monitor.sh
        print_status "Script file removed"
    else
        print_warning "Script file not found"
    fi
}

# Remove log files (with user confirmation)
remove_logs() {
    print_status "Log file cleanup..."
    
    if [ -f "/var/log/wifi-monitor.log" ]; then
        echo
        read -p "Remove log files? This will delete all monitoring history. (y/n): 
" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f /var/log/wifi-monitor.log
            print_status "Log file removed"
            
            # Remove log rotation config
            if [ -f "/etc/logrotate.d/wifi-monitor" ]; then
                rm -f /etc/logrotate.d/wifi-monitor
                print_status "Log rotation config removed"
            fi
        else
            print_status "Log files kept"
        fi
    else
        print_warning "Log file not found"
    fi
}

# Remove backups (with user confirmation)
remove_backups() {
    print_status "Backup cleanup..."
    
    if [ -d "/home/smability/backups" ]; then
        echo
        read -p "Remove backup directory? This will delete all script backups. 
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

# Clean up systemd
cleanup_systemd() {
    print_status "Cleaning up systemd..."
    
    # Reload systemd daemon
    systemctl daemon-reload
    
    # Reset failed services
    systemctl reset-failed 2>/dev/null || true
    
    print_status "Systemd cleanup complete"
}

# Verify uninstallation
verify_uninstall() {
    print_status "Verifying uninstallation..."
    
    local issues=0
    
    # Check service file
    if [ -f "/etc/systemd/system/wifi-connect.service" ]; then
        print_warning "✗ Service file still exists"
        ((issues++))
    else
        print_status "✓ Service file removed"
    fi
    
    # Check script file
    if [ -f "/home/smability/industrial-wifi-monitor.sh" ]; then
        print_warning "✗ Script file still exists"
        ((issues++))
    else
        print_status "✓ Script file removed"
    fi
    
    # Check if service is still running
    if systemctl is-active --quiet wifi-connect.service; then
        print_warning "✗ Service is still running"
        ((issues++))
    else
        print_status "✓ Service is stopped"
    fi
    
    # Check if service is still enabled
    if systemctl is-enabled --quiet wifi-connect.service 2>/dev/null; then
        print_warning "✗ Service is still enabled"
        ((issues++))
    else
        print_status "✓ Service is disabled"
    fi
    
    if [ $issues -eq 0 ]; then
        print_status "✓ Uninstallation verification successful"
    else
        print_warning "⚠ $issues issues found during verification"
    fi
}

# Show remaining files
show_remaining() {
    print_status "Files that were kept:"
    
    if [ -f "/var/log/wifi-monitor.log" ]; then
        echo "  - /var/log/wifi-monitor.log (log file)"
    fi
    
    if [ -d "/home/smability/backups" ]; then
        echo "  - /home/smability/backups/ (backup directory)"
    fi
    
    if [ -f "/home/smability/wifi-connect" ]; then
        echo "  - /home/smability/wifi-connect (WiFi Connect binary)"
    fi
    
    echo
    print_status "These files can be manually removed if no longer needed."
}

# Main uninstall function
main() {
    print_status "Starting Industrial WiFi Monitor uninstallation..."
    echo
    
    check_root
    stop_service
    remove_service_file
    remove_script
    remove_logs
    remove_backups
    cleanup_systemd
    verify_uninstall
    
    echo
    print_status "Uninstallation complete!"
    echo
    show_remaining
    
    print_status "Thank you for using Industrial WiFi Monitor!"
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
