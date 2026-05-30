# infra

Terraform que provisiona toda a infraestrutura AWS do toy-data-project.

> **Arquitetura atualizada**: Agora usa **Apache Iceberg** + **S3 Tables** para armazenamento otimizado.

> O código das Lambdas fica em `lambdas/` na raiz do projeto.  
> Para desenvolvimento local, use o `docker-compose.yml` com LocalStack.

---

## Arquitetura

```
Sensores / Simulador
       │  POST /temperature
       ▼
  API Gateway (REST) → Lambda Andy
       │  sns:Publish
       ▼
  SNS Topic
       │  raw_message_delivery
       ▼
  SQS Queue  ◄── mensagens acumulam aqui
       │
       │  EventBridge — rate(1 hour)
       ▼
  Lambda Hamm (PyIceberg + PyArrow)
       │  Iceberg append
       ▼
  S3 Tables (Iceberg)
  └── raw.sensor_readings (Parquet comprimido)
       │
       ▼
  Glue Catalog (Federated Database)
       │
       ▼
  Athena (queries + time travel + snapshots)
```

---

## Módulos

| Módulo | O que provisiona |
|---|---|
| `modules/api_gateway` | REST API + stage `v1` + validação de schema JSON + throttling |
| `modules/lambda` | Lambda Andy + Lambda Hamm (PyIceberg) + EventBridge schedule |
| `modules/messaging` | SNS topic + SQS queue + Dead Letter Queue |
| `modules/s3_tables` | S3 Table Bucket (Iceberg) + tabela sensor_readings + Athena results bucket |
| `modules/glue` | Federated database (S3 Tables) + conexão + tabela Iceberg |
| `modules/athena` | Workgroup + 8 named queries (incluindo time travel) |
| `modules/iam` | IAM roles com permissões S3 Tables |

---

## Vantagens do Iceberg + S3 Tables

| Feature | JSON Lines (antes) | Iceberg + S3 Tables (agora) |
|---|---|---|
| Compressão | Nenhuma | Parquet Snappy (~10x menor) |
| Schema Evolution | Manual | Nativo |
| Time Travel | ❌ | ✅ |
| ACID Transactions | ❌ | ✅ |
| Partition Pruning | Partition Projection | Iceberg metadata |
| Compaction | Manual (Glue Job) | Automático |
| Query Performance | Scan completo | Predicate pushdown |

---

## Pré-requisitos

- Terraform >= 1.6
- AWS CLI configurado (`aws configure`)
- Permissões: IAM, Lambda, API Gateway, SNS, SQS, S3, S3 Tables, Glue, Athena, EventBridge, CloudWatch

---

## Uso

Via Makefile na raiz do projeto (recomendado):

```bash
make infra-init     # terraform init
make infra-plan     # terraform plan
make infra-apply    # terraform apply
make infra-outputs  # exibe URLs e nomes dos recursos criados
```

Ou diretamente:

```bash
cd infra
terraform init
terraform plan
terraform apply
```

---

## Variáveis

Todas têm valores padrão. Para sobrescrever, crie `infra/terraform.tfvars`:

```hcl
aws_region               = "us-east-1"
project_name             = "toy-data-project"
glue_database_name       = "toy_data_raw"
hamm_schedule_expression = "rate(1 hour)"

# Opcional — custom domain para o API Gateway (ver seção abaixo)
custom_domain            = "andy-api.k8s.our-cluster.ovh"
```

---

## Custom Domain (DNS externo — OVH)

Por padrão o API Gateway expõe um URL gerado pela AWS:
```
https://<id>.execute-api.us-east-1.amazonaws.com/v1/temperature
```

Para usar um domínio próprio como `andy-api.k8s.our-cluster.ovh/temperature`, defina `custom_domain` no `terraform.tfvars` e siga o processo de dois passos abaixo.

### Passo 1 — Primeiro apply (cria o certificado)

```bash
# terraform.tfvars
custom_domain = "andy-api.k8s.our-cluster.ovh"
```

```bash
make infra-apply
```

O Terraform vai pausar aguardando a validação do certificado ACM. Antes de continuar, pegue o registro de validação:

```bash
terraform -chdir=infra output -json acm_validation_cname
```

Saída esperada:
```json
{
  "name":  "_acme-challenge.andy-api.k8s.our-cluster.ovh.",
  "value": "xxxxxxxxxxxx.acm-validations.aws."
}
```

Crie esse CNAME no painel DNS do OVH:

| Tipo | Nome | Valor |
|---|---|---|
| CNAME | `_acme-challenge.andy-api.k8s` | `xxxxxxxxxxxx.acm-validations.aws.` |

Após criar o registro, aguarde alguns minutos. O Terraform vai detectar a validação e continuar automaticamente.

### Passo 2 — Apontar o domínio para o API Gateway

Após o apply completar, pegue o endpoint regional gerado:

```bash
terraform -chdir=infra output -raw custom_domain_target
```

Saída esperada:
```
xxxxxxxxxx.execute-api.us-east-1.amazonaws.com
```

Crie o segundo CNAME no OVH:

| Tipo | Nome | Valor |
|---|---|---|
| CNAME | `andy-api.k8s` | `xxxxxxxxxx.execute-api.us-east-1.amazonaws.com` |

Após a propagação DNS (~5 minutos), o endpoint estará disponível em:

```
https://andy-api.k8s.our-cluster.ovh/temperature
```

### Resumo dos registros DNS no OVH

| Tipo | Nome | Valor | Finalidade |
|---|---|---|---|
| CNAME | `_acme-challenge.andy-api.k8s` | output `acm_validation_cname.value` | Validar certificado TLS |
| CNAME | `andy-api.k8s` | output `custom_domain_target` | Rotear tráfego para o API Gateway |

### Desabilitar o custom domain

Basta remover (ou deixar vazio) a variável `custom_domain` e rodar `make infra-apply`. O Terraform remove o certificado e o mapeamento, mantendo o API Gateway funcionando pelo URL padrão da AWS.

---

## Outputs

Após o `terraform apply`:

```bash
make infra-outputs
```

| Output | Descrição |
|---|---|
| `api_temperature_endpoint` | URL completa do `POST /temperature` |
| `api_gateway_url` | URL base do API Gateway |
| `sns_topic_arn` | ARN do tópico SNS |
| `sqs_queue_url` | URL da fila SQS |
| `sqs_dlq_url` | URL da Dead Letter Queue |
| `data_lake_bucket` | Nome do bucket S3 do data lake |
| `athena_results_bucket` | Nome do bucket S3 para resultados do Athena |
| `glue_database_name` | Nome do banco no Glue Catalog |
| `glue_table_name` | Nome da tabela no Glue Catalog |
| `athena_workgroup` | Nome do workgroup do Athena |
| `andy_lambda_name` | Nome da Lambda Andy |
| `hamm_lambda_name` | Nome da Lambda Hamm |

---

## Operações manuais

```bash
# Disparar o drain da fila SQS sem esperar o schedule
make infra-hamm-invoke

# Ver a URL do endpoint diretamente
make infra-api-url
```
