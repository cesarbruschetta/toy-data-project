# dev

Recursos para desenvolvimento e teste local do toy-data-project.

## O que tem aqui

```
dev/
├── localstack/
│   ├── init.sh           # Cria SNS, SQS e S3 no LocalStack ao iniciar
│   └── .env.localstack   # Variáveis de ambiente para rodar as Lambdas localmente
└── sensor/
    └── simulator_aws.py  # Simula leituras de sensor enviando para qualquer endpoint HTTP/HTTPS
```

## Opções de teste local

### Opção 1 — Testes unitários com moto (recomendado, sem Docker)

Não precisa de nenhum serviço rodando. O `moto` intercepta as chamadas boto3 em memória.

```bash
# Andy
cd lambdas/andy
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
pytest tests/ -v

# Hamm
cd lambdas/hamm
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
pytest tests/ -v
```

### Opção 2 — LocalStack (testa o fluxo completo SNS → SQS → S3)

Útil para validar o fluxo end-to-end sem gastar na AWS.

**1. Subir o LocalStack:**

```bash
docker compose up localstack
```

O script `dev/localstack/init.sh` roda automaticamente e cria:
- SNS topic: `toy-data-project-temperature`
- SQS queue: `toy-data-project-temperature-queue`
- SQS DLQ: `toy-data-project-temperature-dlq`
- S3 bucket: `toy-data-project-data-lake`

**2. Exportar as variáveis de ambiente:**

```bash
export $(cat dev/localstack/.env.localstack | xargs)
```

**3. Invocar as Lambdas manualmente:**

```bash
# Andy — simula um POST /temperature
python -c "
import json
from lambdas.andy.handler import lambda_handler
event = {
    'httpMethod': 'POST',
    'path': '/temperature',
    'body': json.dumps({'sensor_id': 'buzz', 'temperature': 25.0, 'humidity': 60.0, 'heat_index': 28.0})
}
print(lambda_handler(event, None))
"

# Hamm — drena a fila e grava no S3
python -c "
from lambdas.hamm.handler import lambda_handler
print(lambda_handler({}, None))
"
```

**4. Inspecionar os recursos criados:**

```bash
# Listar mensagens na fila
awslocal sqs receive-message \
  --queue-url http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/toy-data-project-temperature-queue

# Listar arquivos no S3
awslocal s3 ls s3://toy-data-project-data-lake/raw/ --recursive
```

### Opção 3 — Simulador de sensor contra a AWS real

Após o `terraform apply`, aponte o simulador para o API Gateway:

```bash
export API_URL=$(cd infra && terraform output -raw api_temperature_endpoint)
export SENSOR_ID=dev_sensor
export SENSOR_INTERVAL=10

python dev/sensor/simulator_aws.py
```

Ou suba via Docker Compose com o profile `simulator`:

```bash
API_URL=https://xxxx.execute-api.us-east-1.amazonaws.com/v1/temperature \
docker compose --profile simulator up sensor-simulator
```
