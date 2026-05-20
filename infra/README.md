# infra — AWS Serverless

Terraform que provisiona toda a infraestrutura AWS do toy-data-project.

> **Ambiente local de desenvolvimento** → use o `docker-compose.yml` na raiz do projeto.  
> Esta pasta contém exclusivamente o código que provisiona recursos na AWS.

## Arquitetura

```
Sensores (ESP8266 / Simulator)
       │  POST /temperature
       ▼
  API Gateway (REST) → Lambda andy
       │  sns:Publish
       ▼
  SNS Topic
       │  raw_message_delivery
       ▼
  SQS Queue  ←── mensagens acumulam aqui
       │
       │  EventBridge (schedule: rate(1 hour))
       ▼
  Lambda hamm — drena a fila inteira, agrupa por data
       │  s3:PutObject (JSON Lines, 1 arquivo por partição por execução)
       ▼
  S3 Data Lake
  └── raw/toydata-topic-temperature-v1/dt=YYYY-MM-DD/*.jsonl
       │
       ▼
  Glue Catalog (Partition Projection — sem crawler)
       │
       ▼
  Athena (queries + named queries prontas)
```

## Módulos

| Módulo | Recursos provisionados |
|---|---|
| `modules/storage` | S3 data lake + S3 athena results |
| `modules/messaging` | SNS topic + SQS queue + DLQ |
| `modules/iam` | IAM roles para Lambda e Athena |
| `modules/lambda` | Lambda andy + Lambda hamm + EventBridge schedule |
| `modules/api_gateway` | REST API + stage `v1` + throttling |
| `modules/glue` | Glue database + table com Partition Projection |
| `modules/athena` | Workgroup + 4 named queries |

## Pré-requisitos

- Terraform >= 1.6
- AWS CLI configurado (`aws configure`)
- Permissões necessárias: IAM, Lambda, API Gateway, SNS, SQS, S3, Glue, Athena, EventBridge

## Uso

```bash
cd infra

terraform init
terraform plan
terraform apply
```

Ou via Makefile:

```bash
make init
make plan
make apply
```

## Variáveis

Todas têm valores padrão. Para sobrescrever, crie um arquivo `terraform.tfvars`:

```hcl
aws_region               = "us-east-1"
project_name             = "toy-data-project"
glue_database_name       = "toy_data_raw"
topic_name               = "toydata-topic-temperature-v1"
raw_prefix               = "raw"
hamm_schedule_expression = "rate(1 hour)"
```

## Lambdas

O código das Lambdas fica em `lambdas/`:

- `lambdas/andy/handler.py` — recebe HTTP do API Gateway e publica no SNS
- `lambdas/hamm/handler.py` — drena a SQS e grava JSON Lines no S3

O Terraform empacota os zips automaticamente via `archive_file` — não é necessário nenhum passo manual.
