#!/usr/bin/env python3
"""
AWS IoT Core Integration for WaterFeature8
Creates an API endpoint for the WaterFeature8 device using AWS IoT Core
"""

import json
import time
import ssl
import threading
from datetime import datetime
from typing import Dict, Optional
import paho.mqtt.client as mqtt

# Import our WaterFeature8 library
from waterFeatLib import WaterFeature8

class WaterFeature8IoT:
    """AWS IoT Core integration for WaterFeature8 device"""
    
    def __init__(self, 
                 device_id: str = "waterfeature8-001",
                 aws_iot_endpoint: str = "a25a4lvtk4epd1-ats.iot.us-east-1.amazonaws.com",
                 ca_cert_path: str = "certs/AmazonRootCA1.pem",
                 cert_path: str = "certs/device-certificate.pem.crt",
                 private_key_path: str = "certs/private.pem.key",
                 serial_port: str = '/dev/tty.usbserial-14110'):
        
        self.device_id = device_id
        self.aws_iot_endpoint = aws_iot_endpoint
        self.ca_cert_path = ca_cert_path
        self.cert_path = cert_path
        self.private_key_path = private_key_path
        
        # MQTT Topics
        self.topic_telemetry = f"waterfeature8/{device_id}/telemetry"
        self.topic_status = f"waterfeature8/{device_id}/status"
        self.topic_command = f"waterfeature8/{device_id}/command"
        self.topic_response = f"waterfeature8/{device_id}/response"
        
        # Initialize components
        self.waterfeature_device = WaterFeature8(port=serial_port)
        self.mqtt_client = None
        self.connected_to_aws = False
        self.running = False
        
        # Data buffers
        self.latest_reading = None
        self.data_lock = threading.Lock()
        
    def setup_mqtt_client(self):
        """Configure MQTT client for AWS IoT Core"""
        self.mqtt_client = mqtt.Client(client_id=self.device_id)
        
        # Set up SSL/TLS
        context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
        context.check_hostname = False
        context.verify_mode = ssl.CERT_REQUIRED
        context.load_verify_locations(self.ca_cert_path)
        context.load_cert_chain(self.cert_path, self.private_key_path)
        
        self.mqtt_client.tls_set_context(context)
        
        # Set callbacks
        self.mqtt_client.on_connect = self.on_mqtt_connect
        self.mqtt_client.on_disconnect = self.on_mqtt_disconnect
        self.mqtt_client.on_message = self.on_mqtt_message
        self.mqtt_client.on_publish = self.on_mqtt_publish
        
    def on_mqtt_connect(self, client, userdata, flags, rc):
        """Callback for MQTT connection"""
        if rc == 0:
            self.connected_to_aws = True
            print(f"Connected to AWS IoT Core with result code {rc}")
            
            # Subscribe to command topic
            client.subscribe(self.topic_command)
            print(f"Subscribed to {self.topic_command}")
            
            # Publish device status
            self.publish_device_status("online")
            
        else:
            print(f"Failed to connect to AWS IoT Core with result code {rc}")
            self.connected_to_aws = False
    
    def on_mqtt_disconnect(self, client, userdata, rc):
        """Callback for MQTT disconnection"""
        self.connected_to_aws = False
        print(f"Disconnected from AWS IoT Core with result code {rc}")
    
    def on_mqtt_message(self, client, userdata, msg):
        """Callback for received MQTT messages (commands)"""
        try:
            topic = msg.topic
            payload = json.loads(msg.payload.decode())
            
            print(f"Received message on {topic}: {payload}")
            
            if topic == self.topic_command:
                self.handle_command(payload)
                
        except Exception as e:
            print(f"Error processing MQTT message: {e}")
    
    def on_mqtt_publish(self, client, userdata, mid):
        """Callback for successful MQTT publish"""
        pass  # Can add logging here if needed
    
    def handle_command(self, command: Dict):
        """Handle incoming commands from AWS IoT Core"""
        try:
            cmd_type = command.get('type', '')
            cmd_id = command.get('command_id', 'unknown')
            
            response = {
                'command_id': cmd_id,
                'device_id': self.device_id,
                'timestamp': datetime.now().isoformat(),
                'status': 'error',
                'message': 'Unknown command'
            }
            
            if cmd_type == 'get_status':
                # Return device status
                device_info = self.waterfeature_device.get_device_info()
                latest_data = self.get_latest_data()
                
                response.update({
                    'status': 'success',
                    'message': 'Device status retrieved',
                    'data': {
                        'device_info': device_info,
                        'latest_reading': latest_data
                    }
                })
                
            elif cmd_type == 'get_reading':
                # Return latest sensor reading
                latest_data = self.get_latest_data()
                
                if latest_data:
                    response.update({
                        'status': 'success',
                        'message': 'Latest reading retrieved',
                        'data': latest_data
                    })
                else:
                    response.update({
                        'status': 'error',
                        'message': 'No recent data available'
                    })
                    
            elif cmd_type == 'send_device_command':
                # Send command to WaterFeature8 device
                device_cmd = command.get('device_command', '')
                
                if self.waterfeature_device.send_command(device_cmd):
                    response.update({
                        'status': 'success',
                        'message': f'Command sent to device: {device_cmd}'
                    })
                else:
                    response.update({
                        'status': 'error',
                        'message': 'Failed to send command to device'
                    })
            
            # Publish response
            self.publish_command_response(response)
            
        except Exception as e:
            print(f"Error handling command: {e}")
    
    def data_received_callback(self, data: Dict):
        """Callback function for new data from WaterFeature8"""
        with self.data_lock:
            self.latest_reading = data
        
        # Publish to AWS IoT Core
        if self.connected_to_aws:
            self.publish_telemetry_data(data)
    
    def get_latest_data(self) -> Optional[Dict]:
        """Get the latest sensor reading"""
        with self.data_lock:
            return self.latest_reading.copy() if self.latest_reading else None
    
    def publish_telemetry_data(self, data: Dict):
        """Publish sensor data to AWS IoT Core"""
        try:
            # Create IoT-friendly payload
            payload = {
                'device_id': self.device_id,
                'timestamp': data['local_timestamp'],
                'epoch_timestamp': data['epoch_timestamp'],
                'device_timestamp': data['device_timestamp'],
                'measurements': {}
            }
            
            # Add sensor measurements
            for var_name, var_data in data['variables'].items():
                payload['measurements'][var_name] = {
                    'value': var_data['value'],
                    'unit': var_data['unit'],
                    'description': var_data['description']
                }
            
            # Publish to telemetry topic
            self.mqtt_client.publish(
                self.topic_telemetry, 
                json.dumps(payload), 
                qos=1
            )
            
        except Exception as e:
            print(f"Error publishing telemetry data: {e}")
    
    def publish_device_status(self, status: str):
        """Publish device status to AWS IoT Core"""
        try:
            payload = {
                'device_id': self.device_id,
                'status': status,
                'timestamp': datetime.now().isoformat(),
                'device_info': self.waterfeature_device.get_device_info()
            }
            
            self.mqtt_client.publish(
                self.topic_status, 
                json.dumps(payload), 
                qos=1
            )
            
        except Exception as e:
            print(f"Error publishing status: {e}")
    
    def publish_command_response(self, response: Dict):
        """Publish command response to AWS IoT Core"""
        try:
            self.mqtt_client.publish(
                self.topic_response, 
                json.dumps(response), 
                qos=1
            )
            
        except Exception as e:
            print(f"Error publishing command response: {e}")
    
    def start(self):
        """Start the AWS IoT integration"""
        try:
            print("Starting WaterFeature8 AWS IoT integration...")
            
            # Connect to WaterFeature8 device
            if not self.waterfeature_device.connect():
                print("Failed to connect to WaterFeature8 device")
                return False
            
            # Set up data callback
            self.waterfeature_device.add_data_callback(self.data_received_callback)
            
            # Setup and connect to AWS IoT Core
            self.setup_mqtt_client()
            self.mqtt_client.connect(self.aws_iot_endpoint, 8883, 60)
            
            # Start MQTT loop in background
            self.mqtt_client.loop_start()
            
            # Start reading from device
            self.waterfeature_device.start_continuous_reading()
            
            self.running = True
            print("WaterFeature8 AWS IoT integration started successfully")
            
            return True
            
        except Exception as e:
            print(f"Error starting AWS IoT integration: {e}")
            return False
    
    def stop(self):
        """Stop the AWS IoT integration"""
        try:
            print("Stopping WaterFeature8 AWS IoT integration...")
            
            self.running = False
            
            # Publish offline status
            if self.connected_to_aws:
                self.publish_device_status("offline")
                time.sleep(1)  # Give time for message to send
            
            # Stop MQTT client
            if self.mqtt_client:
                self.mqtt_client.loop_stop()
                self.mqtt_client.disconnect()
            
            # Stop WaterFeature8 device
            self.waterfeature_device.stop_continuous_reading()
            self.waterfeature_device.disconnect()
            
            print("WaterFeature8 AWS IoT integration stopped")
            
        except Exception as e:
            print(f"Error stopping AWS IoT integration: {e}")
    
    def run(self):
        """Run the integration (blocking)"""
        if not self.start():
            return
        
        try:
            print("WaterFeature8 AWS IoT integration running...")
            print("Published topics:")
            print(f"  - Telemetry: {self.topic_telemetry}")
            print(f"  - Status: {self.topic_status}")
            print(f"  - Responses: {self.topic_response}")
            print(f"Subscribed topics:")
            print(f"  - Commands: {self.topic_command}")
            print("\nPress Ctrl+C to stop...")
            
            while self.running:
                time.sleep(1)
                
        except KeyboardInterrupt:
            print("\nShutdown requested by user")
        finally:
            self.stop()

def main():
    """Main function"""
    # Configuration - Update these values for your AWS IoT setup
    config = {
        'device_id': 'waterfeature8-001',
        'aws_iot_endpoint': 'a25a4lvtk4epd1-ats.iot.us-east-1.amazonaws.com',
        'ca_cert_path': 'certs/AmazonRootCA1.pem',
        'cert_path': 'certs/device-certificate.pem.crt',
        'private_key_path': 'certs/private.pem.key',
        'serial_port': '/dev/tty.usbserial-14110'
    }
    
    # Create and run IoT integration
    iot_device = WaterFeature8IoT(**config)
    iot_device.run()

if __name__ == "__main__":
    main()