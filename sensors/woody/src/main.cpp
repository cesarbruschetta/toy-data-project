
#include "DHT.h"
#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <Adafruit_Sensor.h>
#include "Adafruit_BMP3XX.h"
#include <ArduinoJson.h>
#include <secrets.h>

#define DHTPIN 2
#define DHTTYPE DHT22

#define BMP_SCK 18
#define BMP_MISO 19
#define BMP_MOSI 23
#define BMP_CS 5

#define SEALEVELPRESSURE_HPA (1013.25)

const int DHT_SAMPLING_PERIOD = 1500;
const char *ANDY_API = "http://andy-api.k8s.our-cluster.ovh/temperature";

DHT dht(DHTPIN, DHTTYPE);
Adafruit_BMP3XX bmp;

void setup()
{
  Serial.begin(115200);
  
  // Initialize the LED_BUILTIN pin as an output
  pinMode(LED_BUILTIN, OUTPUT);  

  // Conexão na rede WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  while (WiFi.status() != WL_CONNECTED)
  {
    Serial.print("WI-FI not connected, trying again...");
    delay(500);
  }

  // Inicia o DHT
  dht.begin();
  if (!bmp.begin_I2C()) {  
    // hardware I2C mode, can pass in address & alt Wire
    Serial.println("Could not find a valid BMP3 sensor, check wiring!");
    while (1);
  }

  // Set up oversampling and filter initialization
  bmp.setTemperatureOversampling(BMP3_OVERSAMPLING_8X);
  bmp.setPressureOversampling(BMP3_OVERSAMPLING_4X);
  bmp.setIIRFilterCoeff(BMP3_IIR_FILTER_COEFF_3);
  bmp.setOutputDataRate(BMP3_ODR_50_HZ);

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
      Serial.println("Failed to read from DHT sensor!");
      return;
    }
    if (! bmp.performReading()) {
      Serial.println("Failed to perform reading :(");
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

    // BMP388    
    float temperature_bmp = bmp.temperature;
    float pressure = bmp.pressure / 100.0;
    float altitude = bmp.readAltitude(SEALEVELPRESSURE_HPA);
    payload["temperature_bmp"] = temperature_bmp;
    payload["pressure"] = pressure;
    payload["altitude"] = altitude;

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