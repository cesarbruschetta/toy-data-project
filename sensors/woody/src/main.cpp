#include "Adafruit_BMP280.h"
#include "DHT.h"
#include <Adafruit_Sensor.h>
#include <ArduinoJson.h>
#include <ESP8266HTTPClient.h>
#include <ESP8266WiFi.h>
#include <WiFiClientSecure.h>
#include <secrets.h>

#define DHTPIN   D14
#define DHTTYPE  DHT22
#define LED_ON   LOW
#define LED_OFF  HIGH

#define SEALEVELPRESSURE_HPA (1013.25)

// Intervalo entre leituras em ms
const unsigned long SAMPLING_INTERVAL_MS = 30000;

DHT dht(DHTPIN, DHTTYPE);
Adafruit_BMP280 bmp;

// ─── HTTPS sem verificação de CA ─────────────────────────────────────────────
// O API Gateway da AWS exige HTTPS. setInsecure() mantém a criptografia TLS
// mas não valida a identidade do servidor — aceitável para sensores IoT internos.
WiFiClientSecure wifiClient;

bool bmpAvailable = false;

void connectWifi() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(500);
  }
  Serial.println("\nWi-Fi connected");
}

bool readDHT(float &temperature, float &humidity, float &heatIndex) {
  humidity    = dht.readHumidity();
  temperature = dht.readTemperature();

  if (isnan(temperature) || isnan(humidity)) {
    Serial.println("Failed to read from DHT sensor");
    return false;
  }

  heatIndex = dht.computeHeatIndex(temperature, humidity, false);
  return true;
}

void sendReading(
  float temperature, float humidity, float heatIndex,
  float pressure,    float altitude, float temperatureBmp
) {
  JsonDocument payload;
  payload["sensor_id"]   = SENSOR_ID;
  payload["temperature"] = temperature;
  payload["humidity"]    = humidity;
  payload["heat_index"]  = heatIndex;

  // Campos do BMP280 — só incluídos se o sensor estiver disponível
  if (bmpAvailable) {
    payload["pressure"]        = pressure;
    payload["altitude"]        = altitude;
    payload["temperature_bmp"] = temperatureBmp;
  }

  String body;
  serializeJson(payload, body);

  HTTPClient http;
  http.begin(wifiClient, ANDY_API);
  http.addHeader("Content-Type", "application/json");
  int statusCode = http.POST(body);
  Serial.printf("POST %s → %d\n", ANDY_API, statusCode);
  http.end();
}

void setup() {
  Serial.begin(115200);
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LED_OFF);

  // Desabilita verificação de certificado — ver comentário acima
  wifiClient.setInsecure();

  connectWifi();
  dht.begin();

  // Inicializa BMP280 (endereço I2C padrão: 0x76)
  if (bmp.begin(0x76)) {
    bmpAvailable = true;
    bmp.setSampling(
      Adafruit_BMP280::MODE_FORCED,
      Adafruit_BMP280::SAMPLING_X2,
      Adafruit_BMP280::SAMPLING_X16,
      Adafruit_BMP280::FILTER_X16,
      Adafruit_BMP280::STANDBY_MS_500
    );
    Serial.println("BMP280 initialized");
  } else {
    Serial.println("BMP280 not found — sending DHT22 data only");
  }
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWifi();
    return;
  }

  digitalWrite(LED_BUILTIN, LED_ON);

  float temperature, humidity, heatIndex;
  if (!readDHT(temperature, humidity, heatIndex)) {
    digitalWrite(LED_BUILTIN, LED_OFF);
    delay(SAMPLING_INTERVAL_MS);
    return;
  }

  float pressure = 0, altitude = 0, temperatureBmp = 0;
  if (bmpAvailable && bmp.takeForcedMeasurement()) {
    temperatureBmp = bmp.readTemperature();
    pressure       = bmp.readPressure() / 100.0F; // Pa → hPa
    altitude       = bmp.readAltitude(SEALEVELPRESSURE_HPA);
  }

  sendReading(temperature, humidity, heatIndex, pressure, altitude, temperatureBmp);

  digitalWrite(LED_BUILTIN, LED_OFF);

  delay(SAMPLING_INTERVAL_MS);
}
