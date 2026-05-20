# sensors

Firmware dos sensores físicos do toy-data-project, escritos em C++ com [PlatformIO](https://platformio.org/).

Cada sensor coleta dados ambientais e os envia via HTTP para o endpoint `POST /temperature` do API Gateway.

```
sensors/
├── buzz/           # ESP8266 + DHT22
│   ├── platformio.ini
│   └── src/
│       ├── main.cpp
│       └── secrets_example.h
└── woody/          # ESP8266 + DHT22 + BMP280 (em desenvolvimento)
    ├── platformio.ini
    └── src/
        ├── main.cpp
        └── secrets_example.h
```

---

## Buzz

Hardware: **ESP8266 (ESP-01)** + **DHT22**

Coleta a cada ~2 segundos:
- `temperature` — temperatura em °C
- `humidity` — umidade relativa em %
- `heat_index` — índice de calor calculado pelo DHT22

---

## Woody

Hardware: **ESP8266** + **DHT22** + **BMP280** (em integração)

Além dos dados do DHT22, o BMP280 adiciona (ainda comentado no código):
- `pressure` — pressão atmosférica em hPa
- `altitude` — altitude em metros
- `temperature_bmp` — temperatura pelo BMP280

---

## Configuração

Copie o arquivo de exemplo e preencha com suas credenciais antes de compilar:

```bash
cp sensors/buzz/src/secrets_example.h sensors/buzz/src/secrets.h
```

```cpp
// sensors/buzz/src/secrets.h
const char* WIFI_SSID     = "sua-rede-wifi";
const char* WIFI_PASSWORD = "sua-senha-wifi";
const char* SENSOR_ID     = "buzz";
const char* ANDY_API      = "https://<id>.execute-api.us-east-1.amazonaws.com/v1/temperature";
```

Para pegar a URL do `ANDY_API` após o `terraform apply`:

```bash
make infra-api-url
# ou, se tiver custom domain:
terraform -chdir=infra output -raw custom_domain_url
```

> `secrets.h` está no `.gitignore` — nunca commite credenciais.

---

## HTTPS no ESP8266

O API Gateway da AWS aceita **apenas HTTPS**. O firmware usa `WiFiClientSecure` com `setInsecure()`, que mantém a criptografia TLS mas não valida a identidade do servidor — comportamento padrão e aceitável para sensores IoT em rede doméstica.

```cpp
WiFiClientSecure wifiClient;
wifiClient.setInsecure(); // TLS ativo, sem verificação de CA
```

---

## Build e upload

```bash
cd sensors/buzz

# Compilar
pio run

# Compilar e fazer upload para o dispositivo
pio run --target upload

# Monitor serial (debug)
pio device monitor
```
