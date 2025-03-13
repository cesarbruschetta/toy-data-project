
#include "DHT.h"
#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <ArduinoJson.h>
#include <secrets.h>

#define DHTPIN 2
#define DHTTYPE DHT22

const int DHT_SAMPLING_PERIOD = 2000;
const char *ANDY_API = "https://andy-api.k8s.our-cluster.ovh/temperature";

DHT dht(DHTPIN, DHTTYPE);

void setup()
{
  // Conexão na rede WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  while (WiFi.status() != WL_CONNECTED)
  {
    delay(500);
  }

  // Inicia o DHT
  dht.begin();
}

void loop()
{
  delay(DHT_SAMPLING_PERIOD);

  if ((WiFi.status() == WL_CONNECTED))
  {

    HTTPClient http;
    WiFiClient client;
    JsonDocument payload;

    http.begin(client, ANDY_API); // HTTP
    http.addHeader("Content-Type", "application/json");

    float humidity = dht.readHumidity();
    float temperature = dht.readTemperature();
    if (isnan(temperature) || isnan(humidity)) {
      return;
    }
    
    float hic = dht.computeHeatIndex(temperature, humidity, false);
    payload["sensor_id"] = SENSOR_ID;
    payload["temperature"] = temperature;
    payload["humidity"] = humidity;
    payload["heat_index"] = hic;

    // Serialize JSON document
    String body;
    serializeJson(payload, body);

    // start connection and send HTTP header and body
    http.POST(body);

    // Free resources
    http.end();
  }
}