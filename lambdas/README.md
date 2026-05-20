# lambdas

Funções AWS Lambda do toy-data-project. Cada função tem seu próprio virtualenv, dependências e testes — pode ser desenvolvida e testada de forma independente, sem Terraform ou AWS.

```
lambdas/
├── andy/                   # Producer: recebe HTTP do API Gateway e publica no SNS
│   ├── handler.py
│   ├── requirements.txt
│   └── tests/
│       └── test_handler.py
└── hamm/                   # Consumer: drena SQS e grava JSON Lines no S3
    ├── handler.py
    ├── requirements.txt
    └── tests/
        └── test_handler.py
```

---

## Setup

```bash
make lambda-setup
```

Ou manualmente:

```bash
python -m venv lambdas/andy/.venv
lambdas/andy/.venv/bin/pip install -r lambdas/andy/requirements.txt

python -m venv lambdas/hamm/.venv
lambdas/hamm/.venv/bin/pip install -r lambdas/hamm/requirements.txt
```

---

## Testes

Os testes usam [moto](https://github.com/getmoto/moto) para mockar SNS, SQS e S3 em memória. Nenhum serviço precisa estar rodando.

```bash
make lambda-test        # roda Andy e Hamm
make lambda-test-andy   # só Andy
make lambda-test-hamm   # só Hamm
```

---

## Invocação local via LocalStack

Com o LocalStack rodando (`make dev-up`) e as variáveis exportadas:

```bash
export $(cat dev/localstack/.env.localstack | xargs)

make lambda-invoke-andy   # simula POST /temperature → SNS → SQS
make lambda-invoke-hamm   # drena a fila SQS → S3
```

---

## Andy — Lambda Producer

**Handler:** `andy/handler.py`  
**Runtime:** Python 3.12  
**Trigger:** API Gateway REST — `POST /temperature`, `GET /health-check`

Valida o payload recebido, adiciona o `timestamp` de ingestão e publica no SNS.

Variáveis de ambiente:

| Variável | Descrição |
|---|---|
| `SNS_TOPIC_ARN` | ARN do tópico SNS para publicação |

Payload esperado:

```json
{
  "sensor_id": "buzz",
  "temperature": 24.5,
  "humidity": 65.0,
  "heat_index": 27.75
}
```

Campos opcionais: `pressure`, `altitude`, `temperature_bmp`.

---

## Hamm — Lambda Consumer

**Handler:** `hamm/handler.py`  
**Runtime:** Python 3.12  
**Trigger:** EventBridge schedule (padrão: `rate(1 hour)`)

A cada execução drena toda a fila SQS, agrupa os registros por data de partição e grava um único arquivo JSON Lines por partição no S3.

Path no S3: `raw/toydata-topic-temperature-v1/dt=YYYY-MM-DD/<uuid>.jsonl`

Variáveis de ambiente:

| Variável | Descrição |
|---|---|
| `SQS_QUEUE_URL` | URL da fila SQS a drenar |
| `DATA_LAKE_BUCKET` | Nome do bucket S3 de destino |
| `RAW_PREFIX` | Prefixo S3 da raw zone (padrão: `raw`) |
| `SQS_BATCH_SIZE` | Mensagens por chamada ReceiveMessage (padrão: `10`) |

---

## Relação com o Terraform

O Terraform em `infra/` referencia esta pasta via `lambdas_source_dir` e empacota cada função em `.zip` automaticamente no `terraform apply` usando o `archive_file` data source. Nenhum passo manual de build é necessário.
