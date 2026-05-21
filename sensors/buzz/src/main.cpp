#include "DHT.h"
#include <ArduinoJson.h>
#include <ESP8266HTTPClient.h>
#include <ESP8266WiFi.h>
#include <WiFiClientSecure.h>
#include <secrets.h>

#define DHTPIN        2
#define DHTTYPE       DHT22
#define LED_ON        LOW   // LED_BUILTIN é ativo em LOW no ESP8266
#define LED_OFF       HIGH

// Intervalo entre leituras em ms (DHT22 precisa de pelo menos 2s entre amostras)
const unsigned long SAMPLING_INTERVAL_MS = 30000;

DHT dht(DHTPIN, DHTTYPE);

// ─── HTTPS sem verificação de CA ─────────────────────────────────────────────
// O API Gateway da AWS exige HTTPS. O ESP8266 suporta TLS via BearSSL, mas
// verificar a cadeia completa de certificados consome muita memória no ESP-01.
// setInsecure() mantém a criptografia TLS (dados em trânsito protegidos) mas
// não valida a identidade do servidor — aceitável para sensores IoT internos.
WiFiClientSecure wifiClient;

void connectWifi() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
  }
}

bool readSensor(float &temperature, float &humidity, float &heatIndex) {
  humidity    = dht.readHumidity();
  temperature = dht.readTemperature();

  if (isnan(temperature) || isnan(humidity)) {
    return false;
  }

  heatIndex = dht.computeHeatIndex(temperature, humidity, false);
  return true;
}

void sendReading(float temperature, float humidity, float heatIndex) {
  JsonDocument payload;
  payload["sensor_id"]  = SENSOR_ID;
  payload["temperature"] = temperature;
  payload["humidity"]    = humidity;
  payload["heat_index"]  = heatIndex;

  String body;
  serializeJson(payload, body);

  HTTPClient http;
  http.begin(wifiClient, ANDY_API);
  http.addHeader("Content-Type", "application/json");
  http.POST(body);
  http.end();
}

void setup() {
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LED_OFF); // apagado permanentemente

  // Desabilita verificação de certificado — ver comentário acima
  wifiClient.setInsecure();

  connectWifi();
  dht.begin();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWifi();
    return;
  }

  float temperature, humidity, heatIndex;
  if (readSensor(temperature, humidity, heatIndex)) {
    sendReading(temperature, humidity, heatIndex);
  }

  delay(SAMPLING_INTERVAL_MS);
}
