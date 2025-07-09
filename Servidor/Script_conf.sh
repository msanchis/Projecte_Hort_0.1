#!/bin/bash

set -e

echo "🚀 Instalando dependencias del sistema..."

sudo apt update
sudo apt install -y sqlite3 nginx git curl

echo "🔧 Instalando Node.js y npm..."
curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

echo "📁 Creando estructura de proyecto..."
mkdir -p ~/huerto_web/backend
cd ~/huerto_web/backend

echo "🐍 Creando entorno virtual de Python..."
python3 -m venv venv
source venv/bin/activate

echo "📦 Instalando dependencias de Python..."
pip install flask flask-cors paho-mqtt

echo "💾 Creando base de datos SQLite si no existe..."
sqlite3 huerto.db "VACUUM;"

echo "📝 Creando archivo de backend (api.py)..."
cat << 'EOF' > api.py
# ← Pega aquí el contenido completo del archivo api.py que te proporcioné antes
EOF

echo "🔧 Creando archivo de servicio systemd..."
sudo tee /etc/systemd/system/huerto-backend.service > /dev/null << EOF
[Unit]
Description=API Huerto MQTT
After=network.target

[Service]
User=pi
WorkingDirectory=/home/pi/huerto_web/backend
ExecStart=/home/pi/huerto_web/backend/venv/bin/python3 api.py
Restart=always
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

echo "🔄 Habilitando y arrancando servicio..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable huerto-backend
sudo systemctl start huerto-backend

echo "✅ Servicio backend corriendo en http://localhost:5000"

# === FRONTEND ===
echo "🌐 ¿Quieres instalar y compilar el frontend ahora? (s/n)"
read -r RESP
if [[ "$RESP" =~ ^[sS]$ ]]; then
    echo "📦 Inicializando proyecto React con Vite..."
    cd ~/huerto_web
    npm create vite@latest frontend -- --template react
    cd frontend

    echo "📦 Instalando dependencias frontend..."
    npm install
    npm install recharts

    echo "✅ Puedes empezar el frontend con:"
    echo "   cd ~/huerto_web/frontend"
    echo "   npm run dev"
    echo ""
    echo "⚙️ Si deseas usar NGINX para servirlo en producción, ejecuta:"
    echo "   npm run build"
    echo "y copia el contenido de 'dist/' a /var/www/html"
else
    echo "⏭️  Saltando instalación de frontend."
fi

echo "🎉 Instalación completa."
