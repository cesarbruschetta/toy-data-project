# toy-data-project

Pipeline de dados de IoT de ponta a ponta, desde sensores físicos até consultas analíticas na nuvem. Os componentes são nomeados como personagens do Toy Story.

## Fluxo de dados

```
Sensores físicos (Buzz / Woody)
ou Simulador (dev/sensor/simulator_aws.py)
         │
         │  POST /temperature
         ▼
  API Gateway ──► Lambda Andy
                      │  sns:Publish
                      ▼
                  SNS Topic
                      │  raw_message_delivery
                      ▼
                  SQS Queue  ◄── mensagens acumulam aqui
                      │
                      │  EventBridge (schedule: 1h)
                      ▼
                  Lambda Hamm
                      │  s3:PutObject — JSON Lines, 1 arquivo por partição
                      ▼
                  S3 Data Lake
                  └── raw/toydata-topic-temperature-v1/dt=YYYY-MM-DD/
                      │
                      ▼
                  Glue Catalog (Partition Projection — sem crawler)
                      │
                      ▼
                  Athena (queries analíticas)
```

## Schema dos dados

| Campo | Tipo | Origem |
|---|---|---|
| `sensor_id` | string | Sensor |
| `temperature` | double | DHT22 — temperatura em °C |
| `humidity` | double | DHT22 — umidade relativa em % |
| `heat_index` | double | Calculado pelo sensor |
| `pressure` | double | BMP280 — pressão em hPa (opcional) |
| `altitude` | double | BMP280 — altitude em metros (opcional) |
| `temperature_bmp` | double | BMP280 — temperatura (opcional) |
| `timestamp` | bigint | Unix ms — adicionado pela Lambda Andy |
| `ingested_at` | string | ISO 8601 — adicionado pela Lambda Hamm |
| `dt` | date | Partição YYYY-MM-DD — derivado do timestamp |

---

## Estrutura de pastas

```
toy-data-project/
│
├── sensors/                        # Firmware dos sensores físicos (C++ / PlatformIO)
│   ├── buzz/                       # ESP8266 + DHT22
│   └── woody/                      # ESP8266 + DHT22 + BMP280 (em desenvolvimento)
│
├── lambdas/                        # Funções AWS Lambda (Python)
│   ├── andy/                       # Producer: HTTP → SNS
│   │   ├── handler.py
│   │   ├── requirements.txt
│   │   └── tests/test_handler.py
│   └── hamm/                       # Consumer: SQS drain → S3
│       ├── handler.py
│       ├── requirements.txt
│       └── tests/test_handler.py
│
├── infra/                          # Infraestrutura AWS (Terraform)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── api_gateway/            # REST API + stage v1 + throttling
│       ├── athena/                 # Workgroup + 4 named queries
│       ├── glue/                   # Database + tabela com Partition Projection
│       ├── iam/                    # Roles para Lambda Andy, Hamm e Athena
│       ├── lambda/                 # Funções + EventBridge schedule
│       ├── messaging/              # SNS + SQS + DLQ
│       └── storage/                # S3 data lake + S3 athena results
│
├── dev/                            # Recursos para desenvolvimento local
│   ├── localstack/
│   │   ├── init.sh                 # Cria SNS, SQS e S3 no LocalStack ao iniciar
│   │   └── .env.localstack         # Variáveis para rodar as Lambdas localmente
│   └── sensor/
│       └── simulator_aws.py        # Simula leituras de sensor (HTTP/HTTPS)
│
├── Makefile                        # Comandos centralizados do projeto
├── docker-compose.yml              # LocalStack para desenvolvimento local
└── README.md
```

---

## Pré-requisitos

| Ferramenta | Uso |
|---|---|
| Docker + Docker Compose | LocalStack para dev local |
| Python 3.11+ | Lambdas e simulador de sensor |
| Terraform >= 1.6 | Provisionar infraestrutura AWS |
| AWS CLI | Credenciais e operações na AWS |
| awslocal | Inspecionar recursos no LocalStack |
| PlatformIO | Compilar e fazer upload do firmware dos sensores |

---

## Comandos rápidos

O `Makefile` na raiz centraliza todos os fluxos do projeto.

```bash
make          # exibe o menu completo com todos os comandos
```

### Dev local

```bash
make dev-up             # sobe o LocalStack
make dev-status         # lista SNS, SQS e S3 criados
make dev-queue-peek     # inspeciona mensagens na fila SQS
make dev-s3-ls          # lista arquivos gravados no S3 local
make dev-down           # para os containers
```

### Lambdas

```bash
make lambda-setup       # cria virtualenvs e instala dependências
make lambda-test        # roda todos os testes (moto — sem Docker)
make lambda-invoke-andy # invoca a Andy localmente via LocalStack
make lambda-invoke-hamm # invoca a Hamm localmente via LocalStack
```

### Infra AWS

```bash
make infra-init         # terraform init
make infra-plan         # terraform plan
make infra-apply        # terraform apply
make infra-outputs      # exibe URLs e nomes dos recursos
make infra-hamm-invoke  # dispara o drain da fila na AWS manualmente
```

### Sensores

```bash
make sensor-simulator   # roda o simulador apontando para o API Gateway AWS
```

---

## Fluxo de desenvolvimento

```bash
# 1. Instalar dependências das Lambdas
make lambda-setup

# 2. Rodar os testes unitários (sem Docker, sem AWS)
make lambda-test

# 3. Testar o fluxo completo localmente com LocalStack
make dev-up
make lambda-invoke-andy   # publica uma mensagem no SNS → SQS
make lambda-invoke-hamm   # drena a fila e grava no S3
make dev-s3-ls            # confirma que os dados chegaram

# 4. Deploy na AWS
make infra-init
make infra-apply
make infra-outputs        # pega a URL do API Gateway

# 5. Simular sensores contra a AWS real
make sensor-simulator
```

---

## Sensores físicos

### Buzz (`sensors/buzz`)
ESP8266 (ESP-01) + DHT22. Coleta temperatura, umidade e heat index.

### Woody (`sensors/woody`)
ESP8266 + DHT22 + BMP280 (em integração). Adiciona pressão, altitude e temperatura BMP.

**Configuração:**

```bash
cp sensors/buzz/src/secrets_example.h sensors/buzz/src/secrets.h
# edite secrets.h com WIFI_SSID, WIFI_PASSWORD e SENSOR_ID
```

```bash
cd sensors/buzz
pio run --target upload
```

---

## Componentes

### Lambda Andy
Recebe `POST /temperature` do API Gateway, valida o payload e publica no SNS com o timestamp de ingestão.

Rotas: `POST /temperature` · `GET /health-check`

Payload mínimo:
```json
{
  "sensor_id": "buzz",
  "temperature": 24.5,
  "humidity": 65.0,
  "heat_index": 27.75
}
```

### Lambda Hamm
Invocada pelo EventBridge a cada hora. Drena toda a fila SQS, agrupa os registros por data de partição e grava um único arquivo JSON Lines por partição por execução no S3.

### Athena
Quatro named queries disponíveis no workgroup após o `terraform apply`:

| Query | Descrição |
|---|---|
| `latest-sensor-readings` | 100 leituras mais recentes |
| `daily-average-by-sensor` | Média diária por sensor |
| `hourly-average-last-24h` | Média horária das últimas 24h |
| `active-sensors` | Sensores com última data de leitura |

---
