# toy-data-project

Pipeline de dados de IoT de ponta a ponta, desde sensores físicos até consultas analíticas na nuvem. Os componentes do projeto são nomeados como personagens do Toy Story.

## Visão geral

Sensores físicos (ESP8266) ou um simulador de software coletam dados de temperatura, umidade e pressão e os enviam para uma API HTTP. A partir daí, os dados fluem por uma cadeia de mensageria até serem armazenados em um data lake na AWS, onde ficam disponíveis para consulta via Athena.

```
Sensores físicos (Buzz / Woody)
ou Simulador (dev/sensor)
         │
         │  POST /temperature
         ▼
  API Gateway ──► Lambda Andy
                      │  sns:Publish
                      ▼
                  SNS Topic
                      │
                      ▼
                  SQS Queue  ◄── mensagens acumulam aqui
                      │
                      │  EventBridge (schedule: 1h)
                      ▼
                  Lambda Hamm
                      │  s3:PutObject (JSON Lines, particionado por data)
                      ▼
                  S3 Data Lake
                  └── raw/toydata-topic-temperature-v1/dt=YYYY-MM-DD/
                      │
                      ▼
                  Glue Catalog (Partition Projection)
                      │
                      ▼
                  Athena (queries analíticas)
```

## Schema dos dados

Cada leitura de sensor carrega os seguintes campos:

| Campo | Tipo | Descrição |
|---|---|---|
| `sensor_id` | string | Identificador único do sensor |
| `temperature` | double | Temperatura em °C (DHT22) |
| `humidity` | double | Umidade relativa em % (DHT22) |
| `heat_index` | double | Índice de calor calculado |
| `pressure` | double | Pressão atmosférica em hPa (BMP280, opcional) |
| `altitude` | double | Altitude em metros (BMP280, opcional) |
| `temperature_bmp` | double | Temperatura pelo BMP280 (opcional) |
| `timestamp` | bigint | Unix timestamp em ms — adicionado pela Andy API |
| `ingested_at` | string | ISO 8601 — adicionado pela Lambda Hamm |
| `dt` | date | Partição de data (YYYY-MM-DD) |

---

## Estrutura de pastas

```
toy-data-project/
│
├── sensors/                    # Firmware dos sensores físicos (C++ / PlatformIO)
│   ├── buzz/                   # Sensor ESP8266 + DHT22
│   └── woody/                  # Sensor ESP8266 + DHT22 + BMP280 (em desenvolvimento)
│
├── lambdas/                    # Código das funções AWS Lambda (Python)
│   ├── andy/                   # Producer: recebe HTTP do API Gateway e publica no SNS
│   │   ├── handler.py
│   │   ├── requirements.txt
│   │   └── tests/
│   │       └── test_handler.py
│   └── hamm/                   # Consumer: drena SQS e grava JSON Lines no S3
│       ├── handler.py
│       ├── requirements.txt
│       └── tests/
│           └── test_handler.py
│
├── infra/                      # Infraestrutura AWS (Terraform)
│   ├── main.tf                 # Raiz — orquestra todos os módulos
│   ├── variables.tf            # Variáveis globais com valores padrão
│   ├── outputs.tf              # Outputs: URL da API, nomes dos recursos, etc.
│   ├── Makefile                # Atalhos: make plan, make apply, make hamm-invoke
│   └── modules/
│       ├── api_gateway/        # REST API + stage v1 + throttling + validação de schema
│       ├── athena/             # Workgroup + 4 named queries prontas
│       ├── glue/               # Database + tabela com Partition Projection (sem crawler)
│       ├── iam/                # Roles para Lambda Andy, Lambda Hamm e Athena
│       ├── lambda/             # Funções Andy e Hamm + EventBridge schedule
│       ├── messaging/          # SNS topic + SQS queue + Dead Letter Queue
│       └── storage/            # S3 data lake + S3 athena results
│
├── dev/                        # Utilitários para desenvolvimento local
│   ├── grafana/                # Dockerfile e banco do Grafana
│   ├── hive/                   # Dockerfile, core-site.xml e SQL de inicialização do metastore
│   ├── kafka/                  # Script de criação do tópico Kafka
│   ├── sensor/
│   │   ├── simulator.py        # Simulador de sensor para o docker-compose local
│   │   └── simulator_aws.py    # Simulador de sensor apontando para o API Gateway AWS
│   └── trino/                  # Configuração do conector Hive para o Trino
│
├── docker-compose.yml          # Stack completa para desenvolvimento local
└── README.md
```

---

## Ambientes

O projeto tem dois ambientes com stacks distintas:

### Local (desenvolvimento)

Orquestrado pelo `docker-compose.yml`. Replica o pipeline completo localmente usando serviços open source equivalentes aos da AWS.

| Serviço local | Equivalente AWS |
|---|---|
| Kafka + Zookeeper | SNS + SQS |
| Andy API (Node.js/Fastify) | API Gateway + Lambda Andy |
| Hamm Consumer (PySpark) | Lambda Hamm |
| MinIO | S3 |
| Hive Metastore + HiveServer2 | Glue Catalog |
| Trino | Athena |
| Grafana | — |
| sensor-simulator | dev/sensor/simulator.py |

```bash
# Subir o ambiente local completo
docker compose up -d
```

Serviços disponíveis após o start:

| Serviço | URL |
|---|---|
| Andy API | http://localhost:3000 |
| Kafka UI | http://localhost:8080 |
| MinIO Console | http://localhost:9001 |
| Trino | http://localhost:8083 |
| Grafana | http://localhost:3030 |

### AWS (produção)

Provisionado pelo Terraform em `infra/`. Arquitetura 100% serverless.

```bash
cd infra
terraform init
terraform apply
```

Para testar o endpoint após o deploy:

```bash
# Exibe a URL do endpoint
make api-url

# Dispara manualmente o drain da fila SQS
make hamm-invoke
```

Para simular sensores apontando para a AWS:

```bash
API_URL=$(cd infra && terraform output -raw api_temperature_endpoint) \
SENSOR_ID=dev_sensor \
SENSOR_INTERVAL=30 \
python dev/sensor/simulator_aws.py
```

---

## Sensores físicos

Dois sensores ESP8266 programados com PlatformIO:

### Buzz (`sensors/buzz`)

- **Hardware:** ESP8266 (ESP-01) + DHT22
- **Dados:** temperatura, umidade, heat index
- **Endpoint:** `http://andy-api.k8s.our-cluster.ovh/temperature`

### Woody (`sensors/woody`)

- **Hardware:** ESP8266 + DHT22 + BMP280 (em integração)
- **Dados:** temperatura, umidade, heat index + pressão, altitude, temperatura BMP (comentados — em desenvolvimento)

#### Configuração dos sensores

Copie o arquivo de exemplo e preencha com suas credenciais:

```bash
cp sensors/buzz/src/secrets_example.h sensors/buzz/src/secrets.h
```

```cpp
// sensors/buzz/src/secrets.h
const char* WIFI_SSID     = "sua-rede";
const char* WIFI_PASSWORD = "sua-senha";
const char* SENSOR_ID     = "buzz";
```

Para fazer o upload do firmware:

```bash
cd sensors/buzz
pio run --target upload
```

---

## Componentes em detalhe

### Andy API

Código em `lambdas/andy/handler.py` — Python, recebe HTTP do API Gateway e publica no SNS.

**Rotas:**

| Método | Path | Descrição |
|---|---|---|
| `POST` | `/temperature` | Recebe leitura do sensor e publica na fila |
| `GET` | `/health-check` | Verifica se o serviço está no ar |

**Payload esperado:**

```json
{
  "sensor_id": "buzz",
  "temperature": 24.5,
  "humidity": 65.0,
  "heat_index": 27.75
}
```

### Hamm Consumer

Código em `lambdas/hamm/handler.py` — Python, invocada pelo EventBridge a cada hora, drena toda a fila SQS e grava JSON Lines no S3 particionado por data.

### Glue + Athena

A tabela `sensor_readings` usa **Partition Projection** — novas partições de data são reconhecidas automaticamente pelo Athena sem necessidade de crawler ou `MSCK REPAIR TABLE`.

Quatro named queries estão disponíveis no workgroup após o `terraform apply`:

- `latest-sensor-readings` — 100 leituras mais recentes
- `daily-average-by-sensor` — média diária por sensor
- `hourly-average-last-24h` — média horária das últimas 24h
- `active-sensors` — lista de sensores com última data de leitura

---

## Pré-requisitos

| Ferramenta | Uso |
|---|---|
| Docker + Docker Compose | Ambiente local com LocalStack |
| PlatformIO | Compilar e fazer upload do firmware |
| Terraform >= 1.6 | Provisionar infraestrutura AWS |
| AWS CLI + awslocal | Configurar credenciais e inspecionar recursos |
| Python 3.11+ | Lambdas e simulador de sensor |

## Comandos rápidos

O Makefile na raiz centraliza os comandos de todos os contextos do projeto.

```bash
make                    # exibe o menu completo
```

```
Dev local (LocalStack)
  dev-up                Sobe o LocalStack
  dev-down              Para e remove os containers
  dev-status            Mostra SNS, SQS e S3 criados no LocalStack
  dev-queue-peek        Exibe mensagens na fila SQS sem consumir
  dev-s3-ls             Lista arquivos gravados no S3 local

Lambdas
  lambda-setup          Cria virtualenvs e instala dependências
  lambda-test           Roda os testes de ambas as Lambdas
  lambda-invoke-andy    Invoca a Andy localmente via LocalStack
  lambda-invoke-hamm    Invoca a Hamm localmente via LocalStack

Infra (Terraform / AWS)
  infra-init            Inicializa o Terraform
  infra-plan            Mostra o plano de mudanças
  infra-apply           Aplica a infraestrutura na AWS
  infra-outputs         Exibe URLs e nomes dos recursos criados
  infra-hamm-invoke     Dispara manualmente o drain da fila na AWS

Sensores
  sensor-simulator      Roda o simulador apontando para a AWS
```

## Testando as Lambdas localmente

Cada Lambda tem seus próprios testes com mocks da AWS via [moto](https://github.com/getmoto/moto) — nenhuma credencial ou conexão real é necessária.

```bash
# Andy
python -m venv lambdas/andy/.venv
source lambdas/andy/.venv/bin/activate
pip install -r lambdas/andy/requirements.txt
pytest lambdas/andy/tests/ -v

# Hamm
python -m venv lambdas/hamm/.venv
source lambdas/hamm/.venv/bin/activate
pip install -r lambdas/hamm/requirements.txt
pytest lambdas/hamm/tests/ -v
```

---

## Decisões de arquitetura

**Por que SNS + SQS em vez de Kafka na AWS?**  
Kafka requer instâncias dedicadas (MSK mínimo ~$150/mês). SNS + SQS é serverless, escala para zero e custa centavos para o volume deste projeto.

**Por que a Lambda Hamm drena a fila em schedule e não em tempo real?**  
Processar cada mensagem individualmente geraria um PUT no S3 por leitura de sensor (~86.400/mês com 1 sensor). Com o drain agendado de hora em hora, isso cai para ~720 PUTs/mês, reduzindo custo e gerando arquivos maiores que o Athena lê com mais eficiência.

**Por que Partition Projection em vez de Glue Crawler?**  
O crawler custa ~$4,40/mês rodando diariamente. A Partition Projection é gratuita e resolve o mesmo problema para partições baseadas em datas com padrão previsível.
