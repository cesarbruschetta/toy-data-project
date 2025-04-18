
#include "DHT.h"
#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <ArduinoJson.h>
#include <secrets.h>

#define DHTPIN 2
#define DHTTYPE DHT22

const int DHT_SAMPLING_PERIOD = 1500;
const char *ANDY_API = "http://andy-api.k8s.our-cluster.ovh/temperature";

DHT dht(DHTPIN, DHTTYPE);

void setup()
{
  // Initialize the LED_BUILTIN pin as an output
  pinMode(LED_BUILTIN, OUTPUT);  

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
  // Turn the LED on 
  digitalWrite(LED_BUILTIN, LOW); 
  
  if ((WiFi.status() == WL_CONNECTED))
  {

    float humidity = dht.readHumidity();
    float temperature = dht.readTemperature();
    if (isnan(temperature) || isnan(humidity)) {
      return;
    }

    HTTPClient http;
    WiFiClient client;
    http.begin(client, ANDY_API); // HTTP
    http.addHeader("Content-Type", "application/json");

    JsonDocument payload;
    payload["sensor_id"] = SENSOR_ID;

    // DHT22    
    float hic = dht.computeHeatIndex(temperature, humidity, false);
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

  delay(500);
  // Turn the LED off
  digitalWrite(LED_BUILTIN, HIGH);

  delay(DHT_SAMPLING_PERIOD);
}