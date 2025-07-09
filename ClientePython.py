#!/usr/bin/env python3
import paho.mqtt.client as mqtt
import json
import sqlite3
import datetime
import logging
import time
import threading
from typing import Dict, Any

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('huerto_mqtt.log'),
        logging.StreamHandler()
    ]
)

class HuertoMQTTClient:
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.client = mqtt.Client()
        self.db_path = config.get('db_path', 'huerto.db')
        self.mqtt_server = config.get('mqtt_server', 'localhost')
        self.mqtt_port = config.get('mqtt_port', 1883)
        self.mqtt_user = config.get('mqtt_user', 'huerto_user')
        self.mqtt_password = config.get('mqtt_password', 'huerto_pass')
        
        # Inicializar base de datos
        self.init_database()
        
        # Configurar cliente MQTT
        self.setup_mqtt()
        
        # Estadísticas
        self.stats = {
            'messages_received': 0,
            'data_records': 0,
            'status_updates': 0,
            'heartbeats': 0,
            'errors': 0
        }
        
    def init_database(self):
        """Inicializar la base de datos SQLite"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            # Tabla principal de datos de sensores
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS sensor_data (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    device_id TEXT NOT NULL,
                    timestamp INTEGER NOT NULL,
                    temp_ambient REAL,
                    temp_soil REAL,
                    humidity_ambient REAL,
                    humidity_soil REAL,
                    light_level INTEGER,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Tabla de estado de dispositivos
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS device_status (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    device_id TEXT NOT NULL,
                    status TEXT NOT NULL,
                    ip_address TEXT,
                    timestamp INTEGER NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Tabla de heartbeats
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS heartbeats (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    device_id TEXT NOT NULL,
                    uptime INTEGER,
                    timestamp INTEGER NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Crear índices para mejor rendimiento
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_sensor_device_time ON sensor_data(device_id, timestamp)')
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_status_device_time ON device_status(device_id, timestamp)')
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_heartbeat_device_time ON heartbeats(device_id, timestamp)')
            
            conn.commit()
            conn.close()
            logging.info("Base de datos inicializada correctamente")
            
        except Exception as e:
            logging.error(f"Error al inicializar la base de datos: {e}")
            raise
    
    def setup_mqtt(self):
        """Configurar cliente MQTT"""
        self.client.username_pw_set(self.mqtt_user, self.mqtt_password)
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.client.on_disconnect = self.on_disconnect
        
    def on_connect(self, client, userdata, flags, rc):
        """Callback de conexión MQTT"""
        if rc == 0:
            logging.info("Conectado al broker MQTT")
            # Suscribirse a todos los topics del huerto
            topics = [
                "huerto/+/data",
                "huerto/+/status", 
                "huerto/+/heartbeat"
            ]
            for topic in topics:
                client.subscribe(topic)
                logging.info(f"Suscrito a: {topic}")
        else:
            logging.error(f"Error de conexión MQTT: {rc}")
    
    def on_message(self, client, userdata, msg):
        """Callback para mensajes MQTT"""
        try:
            self.stats['messages_received'] += 1
            topic = msg.topic
            payload = msg.payload.decode('utf-8')
            
            logging.info(f"Mensaje recibido en {topic}: {payload}")
            
            # Parsear JSON
            try:
                data = json.loads(payload)
            except json.JSONDecodeError as e:
                logging.error(f"Error al parsear JSON: {e}")
                self.stats['errors'] += 1
                return
            
            # Procesar según el tipo de topic
            if '/data' in topic:
                self.process_sensor_data(data)
            elif '/status' in topic:
                self.process_status_update(data)
            elif '/heartbeat' in topic:
                self.process_heartbeat(data)
                
        except Exception as e:
            logging.error(f"Error procesando mensaje: {e}")
            self.stats['errors'] += 1
    
    def process_sensor_data(self, data: Dict[str, Any]):
        """Procesar datos de sensores"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO sensor_data 
                (device_id, timestamp, temp_ambient, temp_soil, humidity_ambient, humidity_soil, light_level)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (
                data.get('device_id'),
                data.get('timestamp'),
                data.get('temp_ambient'),
                data.get('temp_soil'),
                data.get('humidity_ambient'),
                data.get('humidity_soil'),
                data.get('light_level')
            ))
            
            conn.commit()
            conn.close()
            
            self.stats['data_records'] += 1
            logging.info(f"Datos guardados para dispositivo {data.get('device_id')}")
            
        except Exception as e:
            logging.error(f"Error guardando datos de sensores: {e}")
            self.stats['errors'] += 1
    
    def process_status_update(self, data: Dict[str, Any]):
        """Procesar actualizaciones de estado"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO device_status 
                (device_id, status, ip_address, timestamp)
                VALUES (?, ?, ?, ?)
            ''', (
                data.get('device_id'),
                data.get('status'),
                data.get('ip'),
                data.get('timestamp')
            ))
            
            conn.commit()
            conn.close()
            
            self.stats['status_updates'] += 1
            logging.info(f"Estado actualizado para dispositivo {data.get('device_id')}: {data.get('status')}")
            
        except Exception as e:
            logging.error(f"Error guardando estado: {e}")
            self.stats['errors'] += 1
    
    def process_heartbeat(self, data: Dict[str, Any]):
        """Procesar heartbeats"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO heartbeats 
                (device_id, uptime, timestamp)
                VALUES (?, ?, ?)
            ''', (
                data.get('device_id'),
                data.get('uptime'),
                data.get('timestamp')
            ))
            
            conn.commit()
            conn.close()
            
            self.stats['heartbeats'] += 1
            logging.info(f"Heartbeat recibido de {data.get('device_id')}")
            
        except Exception as e:
            logging.error(f"Error guardando heartbeat: {e}")
            self.stats['errors'] += 1
    
    def on_disconnect(self, client, userdata, rc):
        """Callback de desconexión"""
        logging.warning(f"Desconectado del broker MQTT: {rc}")
    
    def send_command(self, device_id: str, command: str):
        """Enviar comando a un dispositivo específico"""
        topic = f"huerto/{device_id}/command"
        result = self.client.publish(topic, command)
        if result.rc == 0:
            logging.info(f"Comando '{command}' enviado a {device_id}")
        else:
            logging.error(f"Error enviando comando a {device_id}")
    
    def get_stats(self) -> Dict[str, Any]:
        """Obtener estadísticas del cliente"""
        return self.stats.copy()
    
    def get_latest_data(self, device_id: str = None, limit: int = 10) -> list:
        """Obtener los últimos datos de sensores"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            if device_id:
                cursor.execute('''
                    SELECT * FROM sensor_data 
                    WHERE device_id = ? 
                    ORDER BY created_at DESC 
                    LIMIT ?
                ''', (device_id, limit))
            else:
                cursor.execute('''
                    SELECT * FROM sensor_data 
                    ORDER BY created_at DESC 
                    LIMIT ?
                ''', (limit,))
            
            results = cursor.fetchall()
            conn.close()
            
            return results
            
        except Exception as e:
            logging.error(f"Error obteniendo datos: {e}")
            return []
    
    def print_stats(self):
        """Imprimir estadísticas cada minuto"""
        while True:
            time.sleep(60)
            stats = self.get_stats()
            logging.info(f"Estadísticas - Mensajes: {stats['messages_received']}, "
                        f"Datos: {stats['data_records']}, "
                        f"Estados: {stats['status_updates']}, "
                        f"Heartbeats: {stats['heartbeats']}, "
                        f"Errores: {stats['errors']}")
    
    def run(self):
        """Ejecutar el cliente MQTT"""
        try:
            # Conectar al broker
            logging.info(f"Conectando a {self.mqtt_server}:{self.mqtt_port}")
            self.client.connect(self.mqtt_server, self.mqtt_port, 60)
            
            # Iniciar hilo de estadísticas
            stats_thread = threading.Thread(target=self.print_stats, daemon=True)
            stats_thread.start()
            
            # Mantener el cliente ejecutándose
            self.client.loop_forever()
            
        except KeyboardInterrupt:
            logging.info("Deteniendo cliente MQTT...")
            self.client.disconnect()
        except Exception as e:
            logging.error(f"Error ejecutando cliente: {e}")

def main():
    """Función principal"""
    config = {
        'mqtt_server': '192.168.1.50',  # Cambiar por tu IP
        'mqtt_port': 1883,
        'mqtt_user': 'huerto_user',
        'mqtt_password': 'huerto_pass',
        'db_path': 'huerto.db'
    }
    
    client = HuertoMQTTClient(config)
    
    # Ejemplo de uso interactivo
    print("Cliente MQTT para Huerto Automatizado")
    print("Comandos disponibles:")
    print("  stats - Mostrar estadísticas")
    print("  data [device_id] - Mostrar últimos datos")
    print("  command <device_id> <comando> - Enviar comando")
    print("  quit - Salir")
    
    # Ejecutar cliente en hilo separado
    client_thread = threading.Thread(target=client.run, daemon=True)
    client_thread.start()
    
    # Interfaz interactiva simple
    while True:
        try:
            cmd = input("\n> ").strip().split()
            if not cmd:
                continue
                
            if cmd[0] == 'quit':
                break
            elif cmd[0] == 'stats':
                stats = client.get_stats()
                print(f"Estadísticas actuales: {stats}")
            elif cmd[0] == 'data':
                device_id = cmd[1] if len(cmd) > 1 else None
                data = client.get_latest_data(device_id)
                print(f"Últimos datos: {data}")
            elif cmd[0] == 'command' and len(cmd) >= 3:
                device_id = cmd[1]
                command = ' '.join(cmd[2:])
                client.send_command(device_id, command)
            else:
                print("Comando no reconocido")
                
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"Error: {e}")
    
    print("¡Hasta luego!")

if __name__ == "__main__":
    main()