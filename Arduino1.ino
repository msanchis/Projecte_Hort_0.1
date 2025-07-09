#include <Ethernet.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// Configuración de red
byte mac[] = {0xDE, 0xED, 0xBA, 0xFE, 0xFE, 0xED};
IPAddress ip(192, 168, 1, 100);  // IP fija del Arduino
IPAddress server(192, 168, 1, 50);  // IP del servidor MQTT

// Configuración MQTT
const char* mqtt_server = "192.168.1.50";
const int mqtt_port = 1883;
const char* mqtt_user = "huerto_user";
const char* mqtt_password = "huerto_pass";
const char* device_id = "arduino_01";  // Cambiar para cada Arduino

// Pines de sensores
const int TEMP_AMBIENT_PIN = A0;
const int TEMP_SOIL_PIN = A1;
const int HUMIDITY_AMBIENT_PIN = A2;
const int HUMIDITY_SOIL_PIN = A3;
const int LIGHT_SENSOR_PIN = A4;

// Topics MQTT
const char* topic_base = "huerto/";
char topic_data[50];
char topic_status[50];

// Clientes
EthernetClient ethClient;
PubSubClient client(ethClient);

// Variables para lectura de sensores
struct SensorData {
  float temp_ambient;
  float temp_soil;
  float humidity_ambient;
  float humidity_soil;
  int light_level;
  unsigned long timestamp;
};

// Timing
unsigned long lastSensorReading = 0;
const unsigned long sensorInterval = 30000;  // 30 segundos
unsigned long lastHeartbeat = 0;
const unsigned long heartbeatInterval = 60000;  // 1 minuto

void setup() {
  Serial.begin(9600);
  
  // Configurar topics
  sprintf(topic_data, "%s%s/data", topic_base, device_id);
  sprintf(topic_status, "%s%s/status", topic_base, device_id);
  
  // Inicializar Ethernet
  if (Ethernet.begin(mac) == 0) {
    Serial.println("DHCP falló, usando IP fija");
    Ethernet.begin(mac, ip);
  }
  
  delay(1500);
  Serial.print("IP: ");
  Serial.println(Ethernet.localIP());
  
  // Configurar cliente MQTT
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
  
  // Conectar a MQTT
  connectMQTT();
  
  Serial.println("Sistema inicializado");
}

void loop() {
  // Mantener conexión MQTT
  if (!client.connected()) {
    connectMQTT();
  }
  client.loop();
  
  // Leer sensores cada 30 segundos
  if (millis() - lastSensorReading > sensorInterval) {
    readAndPublishSensors();
    lastSensorReading = millis();
  }
  
  // Enviar heartbeat cada minuto
  if (millis() - lastHeartbeat > heartbeatInterval) {
    publishHeartbeat();
    lastHeartbeat = millis();
  }
  
  delay(1000);
}

void connectMQTT() {
  while (!client.connected()) {
    Serial.print("Conectando a MQTT...");
    
    if (client.connect(device_id, mqtt_user, mqtt_password)) {
      Serial.println("conectado");
      
      // Suscribirse a comandos
      char command_topic[50];
      sprintf(command_topic, "%s%s/command", topic_base, device_id);
      client.subscribe(command_topic);
      
      // Publicar estado de conexión
      publishStatus("online");
      
    } else {
      Serial.print("falló, rc=");
      Serial.print(client.state());
      Serial.println(" reintentando en 5 segundos");
      delay(5000);
    }
  }
}

void callback(char* topic, byte* payload, unsigned int length) {
  String message;
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  
  Serial.print("Mensaje recibido [");
  Serial.print(topic);
  Serial.print("]: ");
  Serial.println(message);
  
  // Procesar comandos
  if (message == "read_sensors") {
    readAndPublishSensors();
  } else if (message == "status") {
    publishStatus("online");
  }
}

void readAndPublishSensors() {
  SensorData data;
  
  // Leer sensores analógicos y convertir a valores reales
  data.temp_ambient = readTemperature(TEMP_AMBIENT_PIN);
  data.temp_soil = readTemperature(TEMP_SOIL_PIN);
  data.humidity_ambient = readHumidity(HUMIDITY_AMBIENT_PIN);
  data.humidity_soil = readHumidity(HUMIDITY_SOIL_PIN);
  data.light_level = readLightLevel(LIGHT_SENSOR_PIN);
  data.timestamp = millis();
  
  // Crear JSON
  StaticJsonDocument<200> doc;
  doc["device_id"] = device_id;
  doc["timestamp"] = data.timestamp;
  doc["temp_ambient"] = data.temp_ambient;
  doc["temp_soil"] = data.temp_soil;
  doc["humidity_ambient"] = data.humidity_ambient;
  doc["humidity_soil"] = data.humidity_soil;
  doc["light_level"] = data.light_level;
  
  char json_string[200];
  serializeJson(doc, json_string);
  
  // Publicar datos
  if (client.publish(topic_data, json_string)) {
    Serial.print("Datos publicados: ");
    Serial.println(json_string);
  } else {
    Serial.println("Error al publicar datos");
  }
}

float readTemperature(int pin) {
  // Simulación de lectura de temperatura (LM35 o similar)
  int reading = analogRead(pin);
  float voltage = reading * 5.0 / 1024.0;
  float temperature = voltage * 100.0;  // LM35: 10mV/°C
  return temperature;
}

float readHumidity(int pin) {
  // Simulación de lectura de humedad
  int reading = analogRead(pin);
  float humidity = map(reading, 0, 1023, 0, 100);
  return humidity;
}

int readLightLevel(int pin) {
  // Lectura de sensor de luz (LDR)
  int reading = analogRead(pin);
  int light_percentage = map(reading, 0, 1023, 0, 100);
  return light_percentage;
}

void publishStatus(const char* status) {
  StaticJsonDocument<100> doc;
  doc["device_id"] = device_id;
  doc["status"] = status;
  doc["timestamp"] = millis();
  doc["ip"] = Ethernet.localIP().toString();
  
  char json_string[100];
  serializeJson(doc, json_string);
  
  client.publish(topic_status, json_string);
}

void publishHeartbeat() {
  StaticJsonDocument<100> doc;
  doc["device_id"] = device_id;
  doc["heartbeat"] = true;
  doc["timestamp"] = millis();
  doc["uptime"] = millis() / 1000;
  
  char json_string[100];
  serializeJson(doc, json_string);
  
  char heartbeat_topic[50];
  sprintf(heartbeat_topic, "%s%s/heartbeat", topic_base, device_id);
  client.publish(heartbeat_topic, json_string);
}