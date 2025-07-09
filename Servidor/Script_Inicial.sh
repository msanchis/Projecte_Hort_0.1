#!/bin/bash

# Script de configuración para servidor de huerto automatizado
# Raspberry Pi 4 con Raspbian
# Autor: Sistema de Huerto Automatizado
# Fecha: $(date)

set -e  # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes con color
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[SETUP]${NC} $1"
}

# Configuraciones del sistema
MQTT_USER="huerto_user"
MQTT_PASSWORD="huerto_pass"
MQTT_CONFIG_DIR="/etc/mosquitto"
MQTT_CONFIG_FILE="$MQTT_CONFIG_DIR/mosquitto.conf"
MQTT_PASSWORD_FILE="$MQTT_CONFIG_DIR/passwd"
DB_PATH="/home/pi/huerto/huerto.db"
PYTHON_SCRIPT_PATH="/home/pi/huerto"
LOG_DIR="/var/log/huerto"
SERVICE_NAME="huerto-mqtt-client"

# Función para verificar si el script se ejecuta como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Este script debe ejecutarse como root"
        print_status "Ejecuta: sudo $0"
        exit 1
    fi
}

# Función para crear usuario del sistema si no existe
create_system_user() {
    print_header "Configurando usuario del sistema"
    
    if ! id "pi" &>/dev/null; then
        print_status "Creando usuario pi"
        useradd -m -s /bin/bash pi
        usermod -aG sudo pi
    else
        print_status "Usuario pi ya existe"
    fi
    
    # Crear directorio de trabajo
    mkdir -p "$PYTHON_SCRIPT_PATH"
    mkdir -p "$LOG_DIR"
    chown -R pi:pi "$PYTHON_SCRIPT_PATH"
    chown -R pi:pi "$LOG_DIR"
}

# Función para actualizar el sistema
update_system() {
    print_header "Actualizando sistema"
    
    print_status "Actualizando lista de paquetes"
    apt update
    
    print_status "Actualizando paquetes instalados"
    apt upgrade -y
    
    print_status "Instalando paquetes base"
    apt install -y curl wget git vim htop tree
}

# Función para instalar SQLite
install_sqlite() {
    print_header "Instalando SQLite"
    
    apt install -y sqlite3 libsqlite3-dev
    
    # Verificar instalación
    if command -v sqlite3 &> /dev/null; then
        SQLITE_VERSION=$(sqlite3 --version | cut -d' ' -f1)
        print_status "SQLite $SQLITE_VERSION instalado correctamente"
    else
        print_error "Error instalando SQLite"
        exit 1
    fi
}

# Función para instalar Python y dependencias
install_python() {
    print_header "Instalando Python y dependencias"
    
    apt install -y python3 python3-pip python3-venv python3-dev
    
    # Crear entorno virtual
    print_status "Creando entorno virtual Python"
    sudo -u pi python3 -m venv "$PYTHON_SCRIPT_PATH/venv"
    
    # Activar entorno virtual e instalar dependencias
    print_status "Instalando dependencias Python"
    sudo -u pi bash -c "source $PYTHON_SCRIPT_PATH/venv/bin/activate && pip install --upgrade pip"
    sudo -u pi bash -c "source $PYTHON_SCRIPT_PATH/venv/bin/activate && pip install paho-mqtt"
    
    # Verificar instalación
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version)
        print_status "$PYTHON_VERSION instalado correctamente"
    else
        print_error "Error instalando Python"
        exit 1
    fi
}

# Función para instalar Mosquitto
install_mosquitto() {
    print_header "Instalando Mosquitto MQTT Broker"
    
    apt install -y mosquitto mosquitto-clients
    
    # Verificar instalación
    if command -v mosquitto &> /dev/null; then
        MOSQUITTO_VERSION=$(mosquitto -h 2>&1 | grep "mosquitto version" | cut -d' ' -f3)
        print_status "Mosquitto $MOSQUITTO_VERSION instalado correctamente"
    else
        print_error "Error instalando Mosquitto"
        exit 1
    fi
}

# Función para configurar Mosquitto
configure_mosquitto() {
    print_header "Configurando Mosquitto"
    
    # Detener servicio para configuración
    systemctl stop mosquitto
    
    # Backup del archivo de configuración original
    if [ -f "$MQTT_CONFIG_FILE" ]; then
        cp "$MQTT_CONFIG_FILE" "$MQTT_CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Crear archivo de configuración
    print_status "Creando archivo de configuración"
    cat > "$MQTT_CONFIG_FILE" << EOF
# Configuración de Mosquitto para Huerto Automatizado
# Archivo generado automáticamente

# Puerto y binding
port 1883
bind_address 0.0.0.0

# Archivos de log
log_dest file /var/log/mosquitto/mosquitto.log
log_dest stdout
log_type error
log_type warning
log_type notice
log_type information
log_timestamp true

# Autenticación
allow_anonymous false
password_file $MQTT_PASSWORD_FILE

# Persistencia
persistence true
persistence_location /var/lib/mosquitto/
persistence_file mosquitto.db

# Configuración de conexión
max_connections 100
max_inflight_messages 20
max_queued_messages 1000

# Timeouts
keepalive 60
retry_interval 20

# Configuración de QoS
upgrade_outgoing_qos false
max_queued_bytes 0

# Configuración de SSL/TLS (comentado por defecto)
# cafile /etc/mosquitto/certs/ca.crt
# certfile /etc/mosquitto/certs/server.crt
# keyfile /etc/mosquitto/certs/server.key

# Configuración de bridge (si se necesita)
# connection bridge-01
# address remote.mqtt.server:1883
# topic huerto/# out 0

# Configuración de websockets (opcional)
# listener 9001
# protocol websockets
EOF

    # Crear usuario MQTT
    print_status "Creando usuario MQTT"
    mosquitto_passwd -c "$MQTT_PASSWORD_FILE" "$MQTT_USER" << EOF
$MQTT_PASSWORD
$MQTT_PASSWORD
EOF

    # Configurar permisos
    chown mosquitto:mosquitto "$MQTT_CONFIG_FILE"
    chown mosquitto:mosquitto "$MQTT_PASSWORD_FILE"
    chmod 600 "$MQTT_PASSWORD_FILE"
    
    # Crear directorio de logs si no existe
    mkdir -p /var/log/mosquitto
    chown mosquitto:mosquitto /var/log/mosquitto
    
    print_status "Configuración de Mosquitto completada"
}

# Función para configurar el firewall
configure_firewall() {
    print_header "Configurando firewall"
    
    # Instalar ufw si no está instalado
    apt install -y ufw
    
    # Configurar reglas básicas
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # Permitir SSH
    ufw allow ssh
    
    # Permitir MQTT
    ufw allow 1883/tcp comment 'MQTT'
    
    # Permitir HTTP y HTTPS (opcional para futura interfaz web)
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    
    # Habilitar firewall
    ufw --force enable
    
    print_status "Firewall configurado"
}

# Función para crear servicio systemd
create_systemd_service() {
    print_header "Creando servicio systemd"
    
    # Crear archivo de servicio
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Huerto MQTT Client Service
After=network.target mosquitto.service
Requires=mosquitto.service

[Service]
Type=simple
User=pi
WorkingDirectory=$PYTHON_SCRIPT_PATH
Environment=PATH=$PYTHON_SCRIPT_PATH/venv/bin
ExecStart=$PYTHON_SCRIPT_PATH/venv/bin/python $PYTHON_SCRIPT_PATH/mqtt_client.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Recargar systemd
    systemctl daemon-reload
    
    print_status "Servicio systemd creado"
}

# Función para configurar log rotation
setup_log_rotation() {
    print_header "Configurando rotación de logs"
    
    # Crear configuración de logrotate
    cat > "/etc/logrotate.d/huerto" << EOF
$LOG_DIR/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 pi pi
}

/var/log/mosquitto/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 mosquitto mosquitto
    postrotate
        systemctl reload mosquitto
    endscript
}
EOF

    print_status "Rotación de logs configurada"
}

# Función para crear script de monitoreo
create_monitoring_script() {
    print_header "Creando script de monitoreo"
    
    cat > "$PYTHON_SCRIPT_PATH/monitor.sh" << 'EOF'
#!/bin/bash

# Script de monitoreo del sistema de huerto
LOG_FILE="/var/log/huerto/monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Iniciando monitoreo del sistema" >> $LOG_FILE

# Verificar servicios
services=("mosquitto" "huerto-mqtt-client")

for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        echo "[$DATE] $service: ACTIVO" >> $LOG_FILE
    else
        echo "[$DATE] $service: INACTIVO - Reiniciando..." >> $LOG_FILE
        systemctl restart $service
    fi
done

# Verificar espacio en disco
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "[$DATE] WARNING: Espacio en disco bajo: $DISK_USAGE%" >> $LOG_FILE
fi

# Verificar memoria
MEMORY_USAGE=$(free | grep Mem | awk '{print ($3/$2) * 100.0}')
if (( $(echo "$MEMORY_USAGE > 80" | bc -l) )); then
    echo "[$DATE] WARNING: Uso de memoria alto: $MEMORY_USAGE%" >> $LOG_FILE
fi

# Verificar temperatura de CPU
CPU_TEMP=$(vcgencmd measure_temp | cut -d= -f2 | cut -d\' -f1)
if (( $(echo "$CPU_TEMP > 70" | bc -l) )); then
    echo "[$DATE] WARNING: Temperatura CPU alta: $CPU_TEMP°C" >> $LOG_FILE
fi

echo "[$DATE] Monitoreo completado" >> $LOG_FILE
EOF

    chmod +x "$PYTHON_SCRIPT_PATH/monitor.sh"
    chown pi:pi "$PYTHON_SCRIPT_PATH/monitor.sh"
    
    # Añadir al crontab
    (crontab -u pi -l 2>/dev/null || echo "") | grep -v "monitor.sh" | (cat; echo "*/5 * * * * $PYTHON_SCRIPT_PATH/monitor.sh") | crontab -u pi -
    
    print_status "Script de monitoreo creado y programado"
}

# Función para crear script de backup
create_backup_script() {
    print_header "Creando script de backup"
    
    cat > "$PYTHON_SCRIPT_PATH/backup.sh" << 'EOF'
#!/bin/bash

# Script de backup de la base de datos
BACKUP_DIR="/home/pi/huerto/backups"
DB_FILE="/home/pi/huerto/huerto.db"
DATE=$(date '+%Y%m%d_%H%M%S')
BACKUP_FILE="$BACKUP_DIR/huerto_backup_$DATE.db"

mkdir -p $BACKUP_DIR

# Hacer backup de la base de datos
if [ -f "$DB_FILE" ]; then
    sqlite3 "$DB_FILE" ".backup $BACKUP_FILE"
    gzip "$BACKUP_FILE"
    echo "Backup creado: $BACKUP_FILE.gz"
    
    # Mantener solo los últimos 30 backups
    cd $BACKUP_DIR
    ls -t *.gz | tail -n +31 | xargs rm -f
else
    echo "Base de datos no encontrada: $DB_FILE"
fi
EOF

    chmod +x "$PYTHON_SCRIPT_PATH/backup.sh"
    chown pi:pi "$PYTHON_SCRIPT_PATH/backup.sh"
    
    # Añadir al crontab (backup diario a las 2 AM)
    (crontab -u pi -l 2>/dev/null || echo "") | grep -v "backup.sh" | (cat; echo "0 2 * * * $PYTHON_SCRIPT_PATH/backup.sh") | crontab -u pi -
    
    print_status "Script de backup creado y programado"
}

# Función para mostrar información del sistema
show_system_info() {
    print_header "Información del Sistema"
    
    echo "=================================="
    echo "CONFIGURACIÓN DEL SERVIDOR HUERTO"
    echo "=================================="
    echo ""
    echo "🌱 Sistema: $(uname -a)"
    echo "🐍 Python: $(python3 --version)"
    echo "🗃️  SQLite: $(sqlite3 --version | cut -d' ' -f1)"
    echo "📡 Mosquitto: $(mosquitto -h 2>&1 | grep "mosquitto version" | cut -d' ' -f3)"
    echo ""
    echo "🔧 CONFIGURACIÓN MQTT:"
    echo "   - Servidor: $(hostname -I | awk '{print $1}'):1883"
    echo "   - Usuario: $MQTT_USER"
    echo "   - Contraseña: $MQTT_PASSWORD"
    echo ""
    echo "📁 DIRECTORIOS:"
    echo "   - Scripts: $PYTHON_SCRIPT_PATH"
    echo "   - Base de datos: $DB_PATH"
    echo "   - Logs: $LOG_DIR"
    echo ""
    echo "🔴 SERVICIOS:"
    systemctl is-active --quiet mosquitto && echo "   - Mosquitto: ACTIVO" || echo "   - Mosquitto: INACTIVO"
    systemctl is-active --quiet $SERVICE_NAME && echo "   - Cliente Python: ACTIVO" || echo "   - Cliente Python: INACTIVO"
    echo ""
    echo "🔥 COMANDOS ÚTILES:"
    echo "   - Ver logs MQTT: tail -f /var/log/mosquitto/mosquitto.log"
    echo "   - Ver logs cliente: journalctl -u $SERVICE_NAME -f"
    echo "   - Reiniciar Mosquitto: sudo systemctl restart mosquitto"
    echo "   - Reiniciar cliente: sudo systemctl restart $SERVICE_NAME"
    echo "   - Monitorear sistema: $PYTHON_SCRIPT_PATH/monitor.sh"
    echo "   - Hacer backup: $PYTHON_SCRIPT_PATH/backup.sh"
    echo ""
}

# Función para iniciar servicios
start_services() {
    print_header "Iniciando servicios"
    
    # Habilitar e iniciar Mosquitto
    systemctl enable mosquitto
    systemctl start mosquitto
    
    # Esperar a que Mosquitto esté listo
    sleep 5
    
    # Verificar estado de Mosquitto
    if systemctl is-active --quiet mosquitto; then
        print_status "Mosquitto iniciado correctamente"
    else
        print_error "Error iniciando Mosquitto"
        systemctl status mosquitto
        exit 1
    fi
    
    # Nota: El cliente Python se iniciará después de copiarse el script
    print_warning "El cliente Python se iniciará cuando copies el script mqtt_client.py a $PYTHON_SCRIPT_PATH"
    print_status "Para iniciar el cliente: sudo systemctl enable $SERVICE_NAME && sudo systemctl start $SERVICE_NAME"
}

# Función para limpiar instalación
cleanup() {
    print_header "Limpiando instalación"
    
    apt autoremove -y
    apt autoclean
    
    print_status "Limpieza completada"
}

# Función principal
main() {
    print_header "Configuración del Servidor de Huerto Automatizado"
    print_status "Iniciando configuración en Raspberry Pi 4"
    
    # Verificar permisos
    check_root
    
    # Configurar sistema
    create_system_user
    update_system
    
    # Instalar software
    install_sqlite
    install_python
    install_mosquitto
    
    # Configurar servicios
    configure_mosquitto
    configure_firewall
    create_systemd_service
    
    # Configurar monitoreo
    setup_log_rotation
    create_monitoring_script
    create_backup_script
    
    # Iniciar servicios
    start_services
    
    # Limpiar
    cleanup
    
    # Mostrar información
    show_system_info
    
    print_status "¡Configuración completada exitosamente!"
    print_warning "Recuerda copiar el script mqtt_client.py a $PYTHON_SCRIPT_PATH"
    print_warning "Y luego ejecutar: sudo systemctl enable $SERVICE_NAME && sudo systemctl start $SERVICE_NAME"
}

# Ejecutar función principal
main "$@"