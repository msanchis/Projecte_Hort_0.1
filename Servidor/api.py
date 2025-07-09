from flask import Flask, jsonify, request
from flask_cors import CORS
import sqlite3
import paho.mqtt.client as mqtt
import os

app = Flask(__name__)
CORS(app)

DB_PATH = os.getenv('DB_PATH', 'huerto.db')
MQTT_HOST = os.getenv('MQTT_HOST', 'localhost')
MQTT_PORT = int(os.getenv('MQTT_PORT', 1883))
MQTT_USER = os.getenv('MQTT_USER', 'huerto_user')
MQTT_PASS = os.getenv('MQTT_PASS', 'huerto_pass')

mqtt_client = mqtt.Client()
mqtt_client.username_pw_set(MQTT_USER, MQTT_PASS)
mqtt_client.connect(MQTT_HOST, MQTT_PORT, 60)
mqtt_client.loop_start()

@app.route("/api/sensor-data")
def get_sensor_data():
    limit = int(request.args.get("limit", 100))
    device_id = request.args.get("device_id", None)

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    if device_id:
        cursor.execute('''
            SELECT timestamp, temp_ambient, temp_soil, humidity_ambient, humidity_soil, light_level 
            FROM sensor_data WHERE device_id = ? ORDER BY timestamp DESC LIMIT ?
        ''', (device_id, limit))
    else:
        cursor.execute('''
            SELECT timestamp, temp_ambient, temp_soil, humidity_ambient, humidity_soil, light_level 
            FROM sensor_data ORDER BY timestamp DESC LIMIT ?
        ''', (limit,))

    rows = cursor.fetchall()
    conn.close()

    return jsonify([
        {
            "timestamp": row[0],
            "temp_ambient": row[1],
            "temp_soil": row[2],
            "humidity_ambient": row[3],
            "humidity_soil": row[4],
            "light_level": row[5]
        }
        for row in rows[::-1]  # ordenar ascendentemente para los gráficos
    ])

@app.route("/api/devices")
def get_devices():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT DISTINCT device_id FROM sensor_data")
    devices = [row[0] for row in cursor.fetchall()]
    conn.close()
    return jsonify(devices)

@app.route("/api/send-command", methods=["POST"])
def send_command():
    data = request.get_json()
    device_id = data.get("device_id")
    command = data.get("command")

    if not device_id or not command:
        return jsonify({"error": "device_id and command required"}), 400

    topic = f"huerto/{device_id}/command"
    result = mqtt_client.publish(topic, command)
    return jsonify({"status": "sent" if result.rc == 0 else "error"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
