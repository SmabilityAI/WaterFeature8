# Water Feature Controller AWS IoT Service

A systemd service for continuous monitoring and control of water features via AWS 
IoT integration. This service runs the main Python application (`WFaws.py`) as a 
background daemon with automatic restart capabilities.

## Features

- **Continuous Operation**: Runs 24/7 with automatic restart on failure
- **AWS IoT Integration**: Connects to AWS IoT Core for remote monitoring and 
control
- **Network Dependency**: Waits for network connectivity before starting
- **Startup Delay**: 30-second delay to ensure system stability
- **Automatic Recovery**: Restarts service if it crashes or stops unexpectedly

## Service Configuration

### Service File Location
```
/etc/systemd/system/waterfeature.service
```

### Service Configuration
```ini
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
```

## Installation

### Step 1: Create the Service File
```bash
sudo nano /etc/systemd/system/waterfeature.service
```

Copy and paste the service configuration above.

### Step 2: Enable and Start the Service
```bash
# Reload systemd to recognize the new service
sudo systemctl daemon-reload

# Enable the service to start on boot
sudo systemctl enable waterfeature.service

# Start the service immediately
sudo systemctl start waterfeature.service
```

### Step 3: Verify Installation
```bash
# Check service status
sudo systemctl status waterfeature.service

# View real-time logs
sudo journalctl -u waterfeature.service -f

# Check if service is enabled for boot
sudo systemctl is-enabled waterfeature.service
```

## Service Management

### Basic Commands
```bash
# Start the service
sudo systemctl start waterfeature.service

# Stop the service
sudo systemctl stop waterfeature.service

# Restart the service
sudo systemctl restart waterfeature.service

# Check service status
sudo systemctl status waterfeature.service

# Enable service to start on boot
sudo systemctl enable waterfeature.service

# Disable service from starting on boot
sudo systemctl disable waterfeature.service
```

### Monitoring and Logs
```bash
# View recent logs
sudo journalctl -u waterfeature.service

# Follow logs in real-time
sudo journalctl -u waterfeature.service -f

# View logs from specific time
sudo journalctl -u waterfeature.service --since "1 hour ago"

# View logs with specific priority
sudo journalctl -u waterfeature.service -p err
```

## Service Details

### Configuration Explanation

| Parameter | Value | Description |
|-----------|--------|-------------|
| `Description` | Water Feature Controller AWS IoT | Human-readable service 
description |
| `After` | network-online.target | Waits for network connectivity |
| `Wants` | network-online.target | Prefers network but doesn't require it |
| `StartLimitIntervalSec` | 0 | No limit on restart attempts |
| `Type` | simple | Service runs in foreground |
| `Restart` | always | Always restart on failure |
| `RestartSec` | 10 | Wait 10 seconds before restart |
| `User` | smability | Run as smability user |
| `ExecStart` | /usr/bin/python3 /home/smability/WaterFeature8/WFaws.py | Main 
command to execute |
| `WorkingDirectory` | /home/smability/WaterFeature8 | Working directory for the 
script |
| `ExecStartPre` | /bin/sleep 30 | Wait 30 seconds before starting |

### Startup Sequence
1. System boots and reaches `network-online.target`
2. Service waits 30 seconds (`ExecStartPre`)
3. Python script starts in `/home/smability/WaterFeature8/` directory
4. Service monitors and restarts if needed

## Prerequisites

### Required Files
- Python script: `/home/smability/WaterFeature8/WFaws.py`
- Working directory: `/home/smability/WaterFeature8/`
- Python 3 interpreter: `/usr/bin/python3`

### Python Dependencies
Ensure all required Python packages are installed:
```bash
cd /home/smability/WaterFeature8
pip3 install -r requirements.txt
```

### AWS IoT Configuration
- AWS IoT certificates and keys properly configured
- Network connectivity to AWS IoT endpoints
- Proper permissions for IoT operations

## Troubleshooting

### Service Won't Start
```bash
# Check service status for errors
sudo systemctl status waterfeature.service

# View detailed logs
sudo journalctl -u waterfeature.service -n 50

# Test script manually
cd /home/smability/WaterFeature8
python3 WFaws.py
```

### Common Issues

#### 1. Script Not Found
```bash
# Verify script exists
ls -la /home/smability/WaterFeature8/WFaws.py

# Check permissions
sudo chown smability:smability /home/smability/WaterFeature8/WFaws.py
chmod +x /home/smability/WaterFeature8/WFaws.py
```

#### 2. Permission Errors
```bash
# Check file ownership
sudo chown -R smability:smability /home/smability/WaterFeature8/

# Verify user exists
id smability
```

#### 3. Python Dependencies
```bash
# Install missing packages
pip3 install boto3 AWSIoTPythonSDK

# Or install from requirements file
pip3 install -r /home/smability/WaterFeature8/requirements.txt
```

#### 4. Network Issues
```bash
# Test network connectivity
ping google.com

# Check if AWS IoT endpoint is reachable
# (Replace with your actual endpoint)
ping your-aws-iot-endpoint.amazonaws.com
```

### Service Logs Analysis

#### Normal Operation
```
systemd[1]: Started Water Feature Controller AWS IoT.
python3[1234]: [INFO] Connecting to AWS IoT...
python3[1234]: [INFO] Connected successfully
```

#### Error Indicators
```
systemd[1]: waterfeature.service: Main process exited, code=exited, 
status=1/FAILURE
python3[1234]: [ERROR] Failed to connect to AWS IoT
```

## Uninstallation

### Remove Service
```bash
# Stop the service
sudo systemctl stop waterfeature.service

# Disable the service
sudo systemctl disable waterfeature.service

# Remove service file
sudo rm /etc/systemd/system/waterfeature.service

# Reload systemd
sudo systemctl daemon-reload

# Reset failed services
sudo systemctl reset-failed
```

## Integration with WiFi Monitor

This service works alongside the Industrial WiFi Monitor to ensure:
- **Network Recovery**: WiFi monitor maintains connectivity
- **Service Continuity**: Water feature service automatically reconnects after 
network issues
- **Coordinated Logging**: Both services log to system journal for unified 
monitoring

## Security Considerations

- Service runs as `smability` user (non-root)
- AWS IoT certificates should have minimal required permissions
- Consider firewall rules for AWS IoT endpoints
- Regular security updates for Python dependencies

## Support

For issues related to:
- **Service configuration**: Check this documentation
- **Python script errors**: Review `WFaws.py` logs
- **AWS IoT connectivity**: Verify certificates and endpoints
- **Network issues**: Check WiFi monitor service status
