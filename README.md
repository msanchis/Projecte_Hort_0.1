# Projecte_Hort_0.1
Projecte per automatitzar un hort al centre educatiu

# 🌱 Sistema de Huerto Automatizado

Un sistema completo de monitoreo y automatización para huertos utilizando Arduino, Raspberry Pi y protocolo MQTT.

## 📋 Descripción del Proyecto

Este proyecto implementa un sistema de huerto automatizado que utiliza 3 Arduinos para captar datos de sensores (temperatura ambiente, temperatura del suelo, humedad ambiente y del suelo, cantidad de luz y otras variables) y enviarlos mediante el protocolo MQTT a un servidor Mosquitto ejecutándose en una Raspberry Pi 4.

## 🏗️ Arquitectura del Sistema

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Arduino 1  │    │  Arduino 2  │    │  Arduino 3  │
│   Sensores  │    │   Sensores  │    │   Sensores  │
└──────┬──────┘    └──────┬──────┘    └──────┬──────┘
       │                  │                  │
       │            MQTT Protocol            │
       │                  │                  │
       └──────────────────┼──────────────────┘
                          │
                   ┌──────▼──────┐
                   │ Raspberry Pi │
                   │  (Servidor)  │
                   │  - Mosquitto │
                   │  - SQLite    │
                   │  - Python    │
                   └─────────────┘
```

## 🔧 Componentes del Sistema

### 📡 Código Arduino
- **Archivo:** `Arduino1.ino`
- **Librerías necesarias:**
  - `Ethernet.h`
  - `PubSubClient.h`
  - `ArduinoJson.h`

**Características:**
- Lectura de sensores cada 30 segundos
- Comunicación MQTT con formato JSON
- Heartbeat cada minuto
- Comandos remotos
- Reconexión automática

### 🐍 Cliente Python
- **Archivo:** `ClientePython.py.py`
- **Dependencias:**
  - `paho-mqtt`
  - `sqlite3` (incluido en Python)

**Características:**
- Almacenamiento en base de datos SQLite
- Logging completo
- Estadísticas en tiempo real
- Interfaz interactiva
- Manejo de múltiples dispositivos

### 🖥️ Servidor Raspberry Pi
- **Archivo:** `Script_inicial.sh`
- **Sistema:** Raspbian en Raspberry Pi 4

**Servicios instalados:**
- Mosquitto MQTT Broker
- SQLite3
- Python 3 con entorno virtual
- Servicios systemd
- Monitoreo y backup automático

## 🚀 Instalación y Configuración

### 1. Configuración del Servidor (Raspberry Pi)

```bash
# Descargar y ejecutar script de configuración
wget https://raw.githubusercontent.com/tuusuario/huerto-automatizado/main/Script_inicial.sh
chmod +x Script_inicial.sh
sudo ./Script_inicial.sh
```

### 2. Configuración de Arduino

1. **Instalar librerías requeridas:**
   - Ethernet
   - PubSubClient
   - ArduinoJson

2. **Configurar cada Arduino:**
   ```cpp
   // Cambiar para cada dispositivo
   const char* device_id = "arduino_01";  // arduino_02, arduino_03
   
   // Configurar IP y servidor MQTT
   IPAddress ip(192, 168, 1, 100);  // IP única para cada Arduino
   const char* mqtt_server = "192.168.1.50";  // IP de la Raspberry Pi
   ```

3. **Conectar sensores:**
   - Pin A0: Sensor temperatura ambiente
   - Pin A1: Sensor temperatura suelo
   - Pin A2: Sensor humedad ambiente
   - Pin A3: Sensor humedad suelo
   - Pin A4: Sensor de luz

### 3. Configuración del Cliente Python

```bash
# Copiar archivo a la Raspberry Pi
scp ClientePython.py.py pi@192.168.1.50:/home/pi/huerto/

# Iniciar servicio
sudo systemctl enable huerto-mqtt-client
sudo systemctl start huerto-mqtt-client
```

## 📊 Topics MQTT

### Estructura de Topics
```
huerto/
├── arduino_01/
│   ├── data        # Datos de sensores
│   ├── status      # Estado del dispositivo
│   ├── heartbeat   # Señal de vida
│   └── command     # Comandos remotos
├── arduino_02/
│   └── ...
└── arduino_03/
    └── ...
```

### Formato de Mensajes

**Datos de sensores** (`huerto/{device_id}/data`):
```json
{
  "device_id": "arduino_01",
  "timestamp": 1234567890,
  "temp_ambient": 23.5,
  "temp_soil": 18.2,
  "humidity_ambient": 65.0,
  "humidity_soil": 45.0,
  "light_level": 75
}
```

**Estado** (`huerto/{device_id}/status`):
```json
{
  "device_id": "arduino_01",
  "status": "online",
  "timestamp": 1234567890,
  "ip": "192.168.1.100"
}
```

**Heartbeat** (`huerto/{device_id}/heartbeat`):
```json
{
  "device_id": "arduino_01",
  "heartbeat": true,
  "timestamp": 1234567890,
  "uptime": 3600
}
```

## 🗄️ Base de Datos

### Estructura de Tablas

#### `sensor_data`
```sql
CREATE TABLE sensor_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    temp_ambient REAL,
    temp_soil REAL,
    humidity_ambient REAL,
    humidity_soil REAL,
    light_level INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### `device_status`
```sql
CREATE TABLE device_status (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    status TEXT NOT NULL,
    ip_address TEXT,
    timestamp INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### `heartbeats`
```sql
CREATE TABLE heartbeats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    uptime INTEGER,
    timestamp INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 🔧 Configuración Predeterminada

### Credenciales MQTT
- **Usuario:** `huerto_user`
- **Contraseña:** `huerto_pass`
- **Puerto:** `1883`

### Rutas del Sistema
- **Base de datos:** `/home/pi/huerto/huerto.db`
- **Scripts:** `/home/pi/huerto/`
- **Logs:** `/var/log/huerto/`
- **Configuración Mosquitto:** `/etc/mosquitto/mosquitto.conf`

## 🛠️ Comandos Útiles

### Monitoreo de Servicios
```bash
# Ver estado de servicios
sudo systemctl status mosquitto
sudo systemctl status huerto-mqtt-client

# Ver logs en tiempo real
tail -f /var/log/mosquitto/mosquitto.log
journalctl -u huerto-mqtt-client -f
```

### Comandos MQTT
```bash
# Probar conexión
mosquitto_pub -h localhost -u huerto_user -P huerto_pass -t "test" -m "hello"
mosquitto_sub -h localhost -u huerto_user -P huerto_pass -t "huerto/+/data"

# Enviar comandos a Arduino
mosquitto_pub -h localhost -u huerto_user -P huerto_pass -t "huerto/arduino_01/command" -m "read_sensors"
```

### Cliente Python Interactivo
```bash
# Ejecutar cliente con interfaz interactiva
cd /home/pi/huerto
source venv/bin/activate
python ClientePython.py.py

# Comandos disponibles:
# stats - Mostrar estadísticas
# data [device_id] - Ver últimos datos
# command <device_id> <comando> - Enviar comando a Arduino
# quit - Salir
```

### Base de Datos
```bash
# Consultar datos
sqlite3 /home/pi/huerto/huerto.db "SELECT * FROM sensor_data ORDER BY created_at DESC LIMIT 10;"

# Backup manual
/home/pi/huerto/backup.sh

# Monitoreo del sistema
/home/pi/huerto/monitor.sh
```

## 🔒 Seguridad

### Firewall (UFW)
```bash
# Puertos abiertos:
# 22 (SSH)
# 1883 (MQTT)
# 80 (HTTP - opcional)
# 443 (HTTPS - opcional)

# Ver estado del firewall
sudo ufw status
```

### Autenticación MQTT
- Autenticación obligatoria activada
- Usuario y contraseña requeridos
- Archivo de contraseñas protegido

## 📈 Monitoreo y Mantenimiento

### Monitoreo Automático
- **Frecuencia:** Cada 5 minutos
- **Verificaciones:**
  - Estado de servicios
  - Uso de disco (alerta >80%)
  - Uso de memoria (alerta >80%)
  - Temperatura de CPU (alerta >70°C)

### Backup Automático
- **Frecuencia:** Diario a las 2:00 AM
- **Retención:** 30 backups
- **Formato:** Compresión gzip
- **Ubicación:** `/home/pi/huerto/backups/`

### Rotación de Logs
- **Frecuencia:** Diaria
- **Retención:** 7 días
- **Compresión:** Activada
- **Archivos:** Logs del sistema y Mosquitto

## 🐛 Resolución de Problemas

### Arduino no se conecta
1. Verificar configuración de red
2. Comprobar credenciales MQTT
3. Verificar estado del servidor Mosquitto
4. Revisar logs del Arduino en Serial Monitor

### Cliente Python no recibe datos
1. Verificar estado del servicio: `sudo systemctl status huerto-mqtt-client`
2. Revisar logs: `journalctl -u huerto-mqtt-client -f`
3. Comprobar conexión MQTT: `mosquitto_sub -h localhost -u huerto_user -P huerto_pass -t "huerto/+/data"`

### Mosquitto no inicia
1. Verificar configuración: `sudo mosquitto -c /etc/mosquitto/mosquitto.conf -v`
2. Revisar logs: `tail -f /var/log/mosquitto/mosquitto.log`
3. Verificar permisos de archivos de configuración

## 🔄 Actualizaciones

### Actualizar Cliente Python
```bash
# Detener servicio
sudo systemctl stop huerto-mqtt-client

# Actualizar archivo
cp nuevo_ClientePython.py.py /home/pi/huerto/ClientePython.py.py

# Reiniciar servicio
sudo systemctl start huerto-mqtt-client
```

### Actualizar Configuración Arduino
1. Modificar código Arduino
2. Compilar y subir
3. Reiniciar dispositivo

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📞 Soporte

Para soporte técnico:
- Abrir un issue en GitHub
- Verificar logs del sistema
- Consultar la documentación

## 🎯 Roadmap

- [ ] Interfaz web para visualización de datos
- [ ] Notificaciones push
- [ ] Integración con servicios en la nube
- [ ] Soporte para más tipos de sensores
- [ ] Dashboard en tiempo real
- [ ] API REST para acceso a datos
- [ ] Alertas por rangos de valores
- [ ] Integración con sistemas de riego

---

**Desarrollado con ❤️ para la automatización de huertos**

