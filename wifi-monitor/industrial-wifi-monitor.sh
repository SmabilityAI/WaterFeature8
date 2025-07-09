#!/bin/bash

# Industrial-Grade WiFi Monitor
# More aggressive reconnection and faster failover to WiFi Connect
# Save as /home/smability/industrial-wifi-monitor.sh

# Configuration
CHECK_INTERVAL=10          # Check every 10 seconds (more frequent)
PING_TIMEOUT=3            # Ping timeout in seconds
MAX_RECONNECT_ATTEMPTS=6  # Try reconnecting 6 times (1 minute total)
WIFI_CONNECT_DELAY=5      # Wait 5 seconds before starting WiFi Connect

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a /var/log/wifi-monitor.log
}

# Check internet connectivity with multiple fallbacks
check_internet() {
    # Try multiple DNS servers for redundancy
    local dns_servers=("8.8.8.8" "1.1.1.1" "208.67.222.222")
    
    for dns in "${dns_servers[@]}"; do
        if ping -c 1 -W $PING_TIMEOUT "$dns" >/dev/null 2>&1; then
            return 0  # Internet is available
        fi
    done
    return 1  # No internet
}

# Check if WiFi is connected
check_wifi_connected() {
    nmcli device status | grep -q "wifi.*connected"
}

# Get current WiFi connection name
get_current_wifi() {
    nmcli -t -f NAME connection show --active | grep -v "lo\|bridge"
}

# Force reconnect to saved WiFi networks
force_wifi_reconnect() {
    log_message "Forcing WiFi reconnection attempts..."
    
    # Get all saved WiFi connections, sorted by priority
    local wifi_connections
    wifi_connections=$(nmcli -t -f NAME,TYPE connection show | grep 
":802-11-wireless" | cut -d: -f1)
    
    local attempt=1
    for connection in $wifi_connections; do
        if [ $attempt -gt $MAX_RECONNECT_ATTEMPTS ]; then
            break
        fi
        
        log_message "Attempt $attempt: Trying to connect to '$connection'"
        
        # Bring connection down first
        nmcli connection down "$connection" 2>/dev/null
        sleep 2
        
        # Try to connect
        if nmcli connection up "$connection" 2>/dev/null; then
            sleep 5
            if check_internet; then
                log_message "Successfully reconnected to '$connection'"
                return 0
            fi
        fi
        
        ((attempt++))
        sleep 5
    done
    
    log_message "All reconnection attempts failed"
    return 1
}

# Start WiFi Connect
start_wifi_connect() {
    log_message "Starting WiFi Connect captive portal..."
    
    # Kill any existing WiFi Connect processes
    pkill -f wifi-connect 2>/dev/null
    sleep 2
    
    # Start WiFi Connect
    cd /home/smability
    ./wifi-connect &
    local wifi_connect_pid=$!
    
    log_message "WiFi Connect started with PID: $wifi_connect_pid"
    
    # Monitor WiFi Connect process
    while kill -0 $wifi_connect_pid 2>/dev/null; do
        sleep 10
        if check_internet; then
            log_message "Internet restored, stopping WiFi Connect"
            kill $wifi_connect_pid 2>/dev/null
            return 0
        fi
    done
    
    log_message "WiFi Connect process ended"
}

# Main monitoring loop
main() {
    log_message "Industrial WiFi Monitor started"
    log_message "Check interval: ${CHECK_INTERVAL}s, Max reconnect attempts: 
$MAX_RECONNECT_ATTEMPTS"
    
    # Wait for system to fully boot
    sleep 15
    
    local consecutive_failures=0
    local last_known_connection=""
    
    while true; do
        if check_internet; then
            if [ $consecutive_failures -gt 0 ]; then
                local current_connection=$(get_current_wifi)
                log_message "Internet restored via: $current_connection"
                consecutive_failures=0
            fi
            
            # Update last known good connection
            if check_wifi_connected; then
                last_known_connection=$(get_current_wifi)
            fi
            
        else
            ((consecutive_failures++))
            log_message "Internet check failed (failure #$consecutive_failures)"
            
            if [ $consecutive_failures -eq 1 ]; then
                log_message "First failure detected, checking WiFi status..."
                
                if check_wifi_connected; then
                    log_message "WiFi connected but no internet - network issue"
                else
                    log_message "WiFi disconnected - attempting reconnection"
                fi
            fi
            
            # Try to reconnect after 2 consecutive failures (20 seconds)
            if [ $consecutive_failures -eq 2 ]; then
                if force_wifi_reconnect; then
                    consecutive_failures=0
                    continue
                fi
            fi
            
            # Start WiFi Connect after 3 consecutive failures (30 seconds)
            if [ $consecutive_failures -ge 3 ]; then
                log_message "Maximum failures reached, starting captive portal"
                start_wifi_connect
                consecutive_failures=0  # Reset counter after WiFi Connect
            fi
        fi
        
        sleep $CHECK_INTERVAL
    done
}

# Handle script termination
cleanup() {
    log_message "WiFi Monitor shutting down"
    pkill -f wifi-connect 2>/dev/null
    exit 0
}

trap cleanup SIGTERM SIGINT

# Create log file
sudo touch /var/log/wifi-monitor.log
sudo chmod 666 /var/log/wifi-monitor.log

# Start main function
main "$@"
