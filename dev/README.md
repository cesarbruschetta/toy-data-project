# dev

Recursos para desenvolvimento e teste local do toy-data-project.

```
dev/
├── localstack/
│   ├── init.sh           # Cria SNS, SQS e S3 no LocalStack ao iniciar
│   └── .env.localstack   # Variáveis de ambiente para rodar as Lambdas localmente
└── sensor/
    └── simulator_aws.py  # Simula leituras de sensor (HTTP e HTTPS)
```

---

## Opção 1 — Testes unitários com moto (sem Docker)

A forma mais rápida. O `moto` intercepta as chamadas boto3 em memória — nenhum serviço precisa estar rodando.

```bash
make lambda-setup   # cria virtualenvs e instala dependências (só na primeira vez)
make lambda-test    # roda os testes de Andy e Hamm
```

---

## Opção 2 — LocalStack (fluxo completo SNS → SQS → S3)

Útil para validar o fluxo end-to-end sem gastar na AWS.

**1. Subir o LocalStack:**

```bash
make dev-up
```

O script `dev/localstack/init.sh` roda automaticamente e cria:

| Recurso | Nome |
|---|---|
| SNS Topic | `toy-data-project-temperature` |
| SQS Queue | `toy-data-project-temperature-queue` |
| SQS DLQ | `toy-data-project-temperature-dlq` |
| S3 Bucket | `toy-data-project-data-lake` |

**2. Exportar as variáveis de ambiente:**

```bash
export $(cat dev/localstack/.env.localstack | xargs)
```

**3. Invocar as Lambdas:**

```bash
make lambda-invoke-andy   # publica uma mensagem no SNS → SQS
make lambda-invoke-hamm   # drena a fila e grava no S3
```

**4. Inspecionar os resultados:**

```bash
make dev-queue-peek   # mensagens na fila SQS
make dev-s3-ls        # arquivos gravados no S3
make dev-status       # visão geral de todos os recursos
```

**5. Inspecionar manualmente com awslocal:**

```bash
# Ver mensagens na fila
awslocal sqs receive-message \
  --queue-url http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/toy-data-project-temperature-queue \
  --max-number-of-messages 10

# Listar arquivos no S3
awslocal s3 ls s3://toy-data-project-data-lake/raw/ --recursive

# Ler um arquivo gravado
awslocal s3 cp s3://toy-data-project-data-lake/raw/<key> -
```

---

## Opção 3 — Simulador contra a AWS real

Após o `terraform apply`, aponte o simulador para o API Gateway:

```bash
make sensor-simulator
```

Ou manualmente com intervalo customizado:

```bash
API_URL=$(make -s infra-api-url) \
SENSOR_ID=dev_sensor \
SENSOR_INTERVAL=10 \
python dev/sensor/simulator_aws.py
```

Ou via Docker Compose com o profile `simulator`:

```bash
API_URL=https://xxxx.execute-api.us-east-1.amazonaws.com/v1/temperature \
docker compose --profile simulator up sensor-simulator
```
