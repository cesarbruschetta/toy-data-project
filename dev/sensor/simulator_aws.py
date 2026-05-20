"""
Sensor simulator — AWS version.

Simulates IoT sensor readings and sends them to the Andy API Gateway endpoint.
Set API_URL to the full API Gateway URL (e.g. https://xxxx.execute-api.us-east-1.amazonaws.com/dev/temperature).
"""

import http.client
import json
import logging
import os
import random
import ssl
import time
import urllib.parse

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)


def calculate_heat_index(temperature: float, humidity: float) -> float:
    return round(temperature + (0.05 * humidity), 4)


def generate_payload(
    temp_min: float = 15.0,
    temp_max: float = 35.0,
    humid_min: float = 30.0,
    humid_max: float = 90.0,
) -> dict:
    temperature = round(random.uniform(temp_min, temp_max), 1)
    humidity = round(random.uniform(humid_min, humid_max), 1)
    heat_index = calculate_heat_index(temperature, humidity)

    return {
        "sensor_id": os.environ.get("SENSOR_ID", "dev_sensor"),
        "temperature": temperature,
        "humidity": humidity,
        "heat_index": heat_index,
    }


def send_data(api_url: str, payload: dict) -> None:
    parsed = urllib.parse.urlparse(api_url)
    host = parsed.netloc
    path = parsed.path

    headers = {"Content-Type": "application/json"}
    body = json.dumps(payload)

    # Suporta HTTPS (API Gateway) e HTTP (local)
    if parsed.scheme == "https":
        conn = http.client.HTTPSConnection(host, context=ssl.create_default_context())
    else:
        conn = http.client.HTTPConnection(host)

    conn.request("POST", path, body, headers)
    res = conn.getresponse()
    data = res.read().decode("utf-8")

    if res.status == 200:
        logging.info("Sent successfully | status=%d response=%s", res.status, data)
    else:
        logging.error("Failed to send | status=%d response=%s", res.status, data)

    conn.close()


def main() -> None:
    api_url = os.environ.get("API_URL")
    if not api_url:
        raise ValueError("API_URL environment variable is required. "
                         "Set it to the full API Gateway URL, e.g.: "
                         "https://xxxx.execute-api.us-east-1.amazonaws.com/dev/temperature")

    sleep_time = int(os.environ.get("SENSOR_INTERVAL", 30))
    logging.info("Starting simulator | api_url=%s interval=%ds", api_url, sleep_time)

    while True:
        try:
            payload = generate_payload()
            logging.info("Sending payload: %s", payload)
            send_data(api_url, payload)
        except KeyboardInterrupt:
            logging.info("Simulator stopped.")
            break
        except Exception as exc:  # noqa: BLE001
            logging.error("Error: %s", exc)

        time.sleep(sleep_time)


if __name__ == "__main__":
    main()
