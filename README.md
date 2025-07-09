# Projecte_Hort_0.1
Projecte per automatitzar un hort al centre educatiu

📡 Código Arduino
Características principales:
    • Sensores soportados: Temperatura ambiente y suelo, humedad ambiente y suelo, nivel de luz 
    • Comunicación MQTT: Publica datos cada 30 segundos en formato JSON 
    • Heartbeat: Envía señal de vida cada minuto 
    • Comandos remotos: Puede recibir comandos para lecturas bajo demanda 
    • Reconexión automática: Se reconecta automáticamente si se pierde la conexión 
Topics MQTT utilizados:
    • huerto/{device_id}/data - Datos de sensores 
    • huerto/{device_id}/status - Estado del dispositivo 
    • huerto/{device_id}/heartbeat - Señal de vida 
    • huerto/{device_id}/command - Comandos remotos 
🐍 Cliente Python
Características principales:
    • Base de datos SQLite: Almacena todos los datos automáticamente 
    • Logging completo: Registra toda la actividad en archivo y consola 
    • Estadísticas en tiempo real: Monitorea mensajes, errores y rendimiento 
    • Interfaz interactiva: Comandos para consultar datos y enviar comandos 
    • Reconexión automática: Maneja desconexiones y reconexiones 
Tablas de la base de datos:
    • sensor_data - Datos de los sensores 
    • device_status - Estados de los dispositivos 
    • heartbeats - Señales de vida 
🔧 Configuración necesaria
Para Arduino:
    1. Instalar librerías: Ethernet, PubSubClient, ArduinoJson 
    2. Cambiar device_id para cada Arduino (arduino_01, arduino_02, arduino_03) 
    3. Ajustar IPs y credenciales MQTT 
    4. Conectar sensores a los pines analógicos especificados 
Para Python:
    1. Instalar dependencias: pip install paho-mqtt 
    2. Ajustar configuración en la función main() 
    3. El script creará automáticamente la base de datos SQLite 
🎯 Uso del sistema
Comandos disponibles en Python:
    • stats - Mostrar estadísticas 
    • data [device_id] - Ver últimos datos 
    • command <device_id> <comando> - Enviar comando a Arduino 
Comandos para Arduino:
    • read_sensors - Forzar lectura de sensores 
    • status - Solicitar estado del dispositivo 
El sistema está diseñado para ser robusto y escalable. Cada Arduino puede funcionar independientemente y el cliente Python maneja múltiples dispositivos simultáneamente. Los datos se almacenan de forma persistente y el sistema incluye monitoreo completo de la salud de los dispositivos.

