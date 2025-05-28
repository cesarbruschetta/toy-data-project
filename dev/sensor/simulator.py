import logging
import random
import time
import json
import http.client
import os


logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)


def calculate_heat_index(temperature, humidity):
    """
    Calcula o índice de calor baseado na temperatura e umidade.
    Esta é uma fórmula simplificada. Para maior precisão, existem algoritmos mais complexos.
    """
    return round(temperature + (0.05 * humidity), 4)


def generate_random_weather_payload(
    temp_min=15.0, temp_max=35.0, humid_min=30.0, humid_max=90.0
):
    """
    Gera um payload de dados meteorológicos com valores aleatórios.

    Parâmetros:
    - temp_min: temperatura mínima (°C)
    - temp_max: temperatura máxima (°C)
    - humid_min: umidade mínima (%)
    - humid_max: umidade máxima (%)

    Retorna:
    - Um dicionário com temperature, humidity e heat_index
    """
    temperature = round(random.uniform(temp_min, temp_max), 1)
    humidity = round(random.uniform(humid_min, humid_max), 1)
    heat_index = calculate_heat_index(temperature, humidity)

    return temperature, humidity, heat_index


def send_temperature_data():
    """
    Sends temperature data to the specified URL.
    """
    logging.info("Starting to send temperature data...")

    # Define the URL and payload
    random_temperature, random_humidity, heat_index = generate_random_weather_payload()
    payload = {
        "sensor_id": "dev_sensor",
        "temperature": random_temperature,
        "humidity": random_humidity,
        "heat_index": heat_index,
    }
    headers = {
        "Content-Type": "application/json",
    }

    # Send the POST request
    conn = http.client.HTTPConnection(
        os.environ["API_HOST"]
    )
    conn.request("POST", "/temperature", json.dumps(payload), headers)
    res = conn.getresponse()
    data = res.read().decode("utf-8")

    # Log the response
    if res.status == 200:
        logging.info("Data sent successfully: %s", data)
    else:
        logging.error("Failed to send data: %s", data)

    logging.info("Finished sending temperature data.")


def main():
    running = True
    sleep_time = int(os.environ.get("SENSOR_INTERVAL", 30))

    while running:
        try:
            logging.info("Sending temperature data...")
            send_temperature_data()
            logging.info(f"Waiting for {sleep_time} seconds before sending the next data...")
            time.sleep(sleep_time)
        except (KeyboardInterrupt, SystemExit):
            logging.info("Stopping the temperature data sender.")
            running = False
        except Exception as e:
            logging.error("An error occurred: %s", str(e))
            running = False


if __name__ == "__main__":
    main()
