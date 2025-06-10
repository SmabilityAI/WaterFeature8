#!/usr/bin/env python3
"""
WaterFeature8 Library
A library for interfacing with WaterFeature8 water quality monitoring device
"""

import serial
import time
import datetime
import threading
import json
from typing import Dict, List, Optional, Callable

class WaterFeature8:
    """WaterFeature8 device interface library"""
    
    def __init__(self, port='/dev/tty.usbserial-14110', baudrate=115200, timeout=1):
        """
        Initialize the WaterFeature8 device connection
        
        Args:
            port (str): Serial port path
            baudrate (int): Baud rate for serial communication
            timeout (float): Read timeout in seconds
        """
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self.serial_conn = None
        self.running = False
        self.data_callbacks = []
        self.latest_data = None
        self.data_lock = threading.Lock()
        
        # Variable definitions
        self.variable_labels = ['EC', 'RTD_EC', 'pH', 'RTD_pH', 'DO', 'RTD_DO', 'ORP']
        self.variable_units = ['μS/cm', '°C', 'pH', '°C', 'mg/L', '°C', 'mV']
        self.variable_descriptions = [
            'Electrical Conductivity',
            'Temperature (EC compensation)',
            'pH Level',
            'Temperature (pH compensation)',
            'Dissolved Oxygen',
            'Temperature (DO compensation)',
            'Oxidation-Reduction Potential'
        ]
    
    def connect(self) -> bool:
        """
        Establish serial connection to WaterFeature8 device
        
        Returns:
            bool: True if connection successful, False otherwise
        """
        try:
            self.serial_conn = serial.Serial(
                port=self.port,
                baudrate=self.baudrate,
                timeout=self.timeout,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE
            )
            print(f"Connected to WaterFeature8 on {self.port} at {self.baudrate} baud")
            return True
        except serial.SerialException as e:
            print(f"Failed to connect to {self.port}: {e}")
            return False
    
    def disconnect(self):
        """Close serial connection and stop reading"""
        self.running = False
        if self.serial_conn and self.serial_conn.is_open:
            self.serial_conn.close()
            print("Disconnected from WaterFeature8")
    
    def parse_data_line(self, line: str) -> Optional[Dict]:
        """
        Parse a line of data from WaterFeature8
        
        Args:
            line (str): Raw data line from device
            
        Returns:
            dict: Parsed data with timestamp and variables, or None if parsing fails
        """
        try:
            parts = line.strip().split(',')
            if len(parts) < 2:
                return None
                
            # First field is device timestamp, rest are variables
            device_timestamp = parts[0]
            raw_variables = parts[1:]
            
            # Create structured data
            variables = {}
            for i, value in enumerate(raw_variables):
                if i < len(self.variable_labels):
                    try:
                        # Convert to appropriate type
                        numeric_value = float(value.strip()) if value.strip() else 0.0
                        variables[self.variable_labels[i]] = {
                            'value': numeric_value,
                            'unit': self.variable_units[i],
                            'description': self.variable_descriptions[i],
                            'raw': value.strip()
                        }
                    except (ValueError, TypeError):
                        variables[self.variable_labels[i]] = {
                            'value': 0.0,
                            'unit': self.variable_units[i],
                            'description': self.variable_descriptions[i],
                            'raw': value.strip()
                        }
            
            parsed_data = {
                'device_timestamp': device_timestamp,
                'local_timestamp': datetime.datetime.now().isoformat(),
                'epoch_timestamp': int(time.time()),
                'variables': variables,
                'device_id': 'WaterFeature8',
                'raw_line': line.strip()
            }
            
            return parsed_data
            
        except Exception as e:
            print(f"Error parsing line '{line.strip()}': {e}")
            return None
    
    def add_data_callback(self, callback: Callable[[Dict], None]):
        """
        Add a callback function to be called when new data is received
        
        Args:
            callback: Function that takes parsed data dict as argument
        """
        self.data_callbacks.append(callback)
    
    def remove_data_callback(self, callback: Callable[[Dict], None]):
        """Remove a data callback function"""
        if callback in self.data_callbacks:
            self.data_callbacks.remove(callback)
    
    def get_latest_data(self) -> Optional[Dict]:
        """
        Get the most recent data reading
        
        Returns:
            dict: Latest parsed data or None if no data available
        """
        with self.data_lock:
            return self.latest_data.copy() if self.latest_data else None
    
    def get_device_info(self) -> Dict:
        """
        Get device information and capabilities
        
        Returns:
            dict: Device information
        """
        return {
            'device_id': 'WaterFeature8',
            'model': 'WaterFeature8',
            'port': self.port,
            'baudrate': self.baudrate,
            'variables': [
                {
                    'name': label,
                    'unit': unit,
                    'description': desc
                }
                for label, unit, desc in zip(
                    self.variable_labels, 
                    self.variable_units, 
                    self.variable_descriptions
                )
            ],
            'status': 'connected' if (self.serial_conn and self.serial_conn.is_open) else 'disconnected'
        }
    
    def start_continuous_reading(self):
        """Start continuous reading in a separate thread"""
        if not self.serial_conn or not self.serial_conn.is_open:
            print("Device not connected")
            return False
        
        self.running = True
        self.read_thread = threading.Thread(target=self._read_loop, daemon=True)
        self.read_thread.start()
        print("Started continuous reading")
        return True
    
    def stop_continuous_reading(self):
        """Stop continuous reading"""
        self.running = False
        if hasattr(self, 'read_thread'):
            self.read_thread.join(timeout=2)
        print("Stopped continuous reading")
    
    def _read_loop(self):
        """Internal continuous reading loop"""
        print("Reading data stream...")
        last_sample_time = 0  # Add this line
        
        while self.running:
            try:
                if self.serial_conn.in_waiting > 0:
                    raw_line = self.serial_conn.readline().decode('utf-8', errors='ignore')
                    
                    if raw_line.strip():
                        current_time = time.time()
                        #parsed_data = self.parse_data_line(raw_line)
                        
                        # Only process data if 60 seconds have passed since last sample
                        if current_time - last_sample_time >= 60:  # 60 seconds = 1 minute
                            parsed_data = self.parse_data_line(raw_line)
                            
                            if parsed_data:
                                # Update latest data
                                with self.data_lock:
                                    self.latest_data = parsed_data
                            
                                # Call all registered callbacks
                                for callback in self.data_callbacks:
                                    try:
                                        callback(parsed_data)
                                    except Exception as e:
                                        print(f"Error in data callback: {e}")
                                        
                            last_sample_time = current_time
                
                time.sleep(0.01)  # Small delay to prevent CPU overload-->report every 3 sec
                
                
            except serial.SerialException as e:
                print(f"Serial error: {e}")
                break
            except Exception as e:
                print(f"Unexpected error in read loop: {e}")
                break
    
    def send_command(self, command: str) -> bool:
        """
        Send command to WaterFeature8 device
        
        Args:
            command (str): Command to send
            
        Returns:
            bool: True if command sent successfully
        """
        if not self.serial_conn or not self.serial_conn.is_open:
            print("Not connected to device")
            return False
            
        try:
            self.serial_conn.write(f"{command}\n".encode())
            print(f"Sent command: {command}")
            return True
        except serial.SerialException as e:
            print(f"Error sending command: {e}")
            return False

# Example usage and testing functions
def print_data_callback(data):
    """Example callback function to print received data"""
    print(f"[{data['local_timestamp']}] Device: {data['device_timestamp']}")
    for var_name, var_data in data['variables'].items():
        print(f"  {var_name}: {var_data['value']} {var_data['unit']} ({var_data['description']})")
    print("-" * 50)

if __name__ == "__main__":
    # Example usage
    device = WaterFeature8()
    
    try:
        if device.connect():
            # Add callback to print data
            device.add_data_callback(print_data_callback)
            
            # Start continuous reading
            device.start_continuous_reading()
            
            print("Press Enter to stop...")
            input()
            
        else:
            print("Failed to connect to device")
            
    except KeyboardInterrupt:
        print("Interrupted by user")
    finally:
        device.stop_continuous_reading()
        device.disconnect()