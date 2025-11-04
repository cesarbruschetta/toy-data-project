
#include "DHT.h"
#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <Adafruit_Sensor.h>
#include "Adafruit_BMP280.h"
#include <ArduinoJson.h>
#include <secrets.h>

#define DHTPIN D14
#define DHTTYPE DHT22


#define SEALEVELPRESSURE_HPA (1013.25)

const int DHT_SAMPLING_PERIOD = 1500;
const char *ANDY_API = "http://czcxb8dz1wg0000rvrt0gxsqiwayyyyyb.oast.pro";

DHT dht(DHTPIN, DHTTYPE);
// Adafruit_BMP280 bmp;

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
  // dht.begin();
  // if (!bmp.begin(0x76))
  // {
  //   // hardware I2C mode, can pass in address & alt Wire
  //   Serial.println("Could not find a valid BMP280 sensor, check wiring or "
  //                  "try a different address!");
  //   return;
  // }

  // /* Default settings from datasheet. */
  // bmp.setSampling(Adafruit_BMP280::MODE_FORCED,     /* Operating Mode. */
  //                 Adafruit_BMP280::SAMPLING_X2,     /* Temp. oversampling */
  //                 Adafruit_BMP280::SAMPLING_X16,    /* Pressure oversampling */
  //                 Adafruit_BMP280::FILTER_X16,      /* Filtering. */
  //                 Adafruit_BMP280::STANDBY_MS_500); /* Standby time. */
}

void loop()
{
  // Turn the LED on
  digitalWrite(LED_BUILTIN, LOW);

  if ((WiFi.status() == WL_CONNECTED))
  {
    float humidity = dht.readHumidity();
    float temperature = dht.readTemperature();
    // if (isnan(temperature) || isnan(humidity))
    // {
    //   Serial.println("Failed to read from DHT sensor!");
    //   return;
    // }
    // if (!bmp.takeForcedMeasurement())
    // {
    //   Serial.println("Failed to perform reading :(");
    //   return;
    // }

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

    // // BMP388
    // float temperature_bmp = bmp.readTemperature();
    // float pressure = bmp.readPressure() / 100.0F; // Convert to hPa
    // float altitude = bmp.readAltitude(SEALEVELPRESSURE_HPA);
    // payload["temperature_bmp"] = temperature_bmp;
    // payload["pressure"] = pressure;
    // payload["altitude"] = altitude;

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