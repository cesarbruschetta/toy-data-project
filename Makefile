.DEFAULT_GOAL := help

# ─── Cores ────────────────────────────────────────────────────────────────────
CYAN  := \033[36m
RESET := \033[0m
BOLD  := \033[1m

# ─── Help ─────────────────────────────────────────────────────────────────────

.PHONY: help
help: ## Mostra este menu de ajuda
	@echo ""
	@echo "$(BOLD)toy-data-project$(RESET)"
	@echo ""
	@echo "$(BOLD)$(CYAN)Dev local (LocalStack)$(RESET)"
	@grep -E '^dev-[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-28s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(BOLD)$(CYAN)Lambdas$(RESET)"
	@grep -E '^lambda-[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-28s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(BOLD)$(CYAN)Infra (Terraform / AWS)$(RESET)"
	@grep -E '^infra-[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-28s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(BOLD)$(CYAN)Sensores$(RESET)"
	@grep -E '^sensor-[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-28s$(RESET) %s\n", $$1, $$2}'
	@echo ""

# ─── Dev local ────────────────────────────────────────────────────────────────

.PHONY: dev-up
dev-up: ## Sobe o LocalStack
	docker compose up localstack -d

.PHONY: dev-down
dev-down: ## Para e remove os containers
	docker compose down

.PHONY: dev-logs
dev-logs: ## Exibe os logs do LocalStack
	docker compose logs -f localstack

.PHONY: dev-status
dev-status: ## Mostra os recursos criados no LocalStack (SNS, SQS, S3)
	@echo "\n$(CYAN)SNS Topics$(RESET)"
	@awslocal sns list-topics --query 'Topics[].TopicArn' --output table 2>/dev/null || echo "  LocalStack não está rodando"
	@echo "\n$(CYAN)SQS Queues$(RESET)"
	@awslocal sqs list-queues --query 'QueueUrls' --output table 2>/dev/null
	@echo "\n$(CYAN)S3 Buckets$(RESET)"
	@awslocal s3 ls 2>/dev/null

.PHONY: dev-queue-peek
dev-queue-peek: ## Exibe as mensagens na fila SQS (sem consumir)
	@awslocal sqs receive-message \
	  --queue-url http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/toy-data-project-temperature-queue \
	  --max-number-of-messages 10 \
	  --output json 2>/dev/null || echo "  Fila vazia ou LocalStack não está rodando"

.PHONY: dev-s3-ls
dev-s3-ls: ## Lista os arquivos gravados no S3 local
	@awslocal s3 ls s3://toy-data-project-data-lake/raw/ --recursive 2>/dev/null || echo "  Bucket vazio ou LocalStack não está rodando"

.PHONY: dev-simulator
dev-simulator: ## Sobe o simulador de sensor apontando para o LocalStack
	docker compose --profile simulator up sensor-simulator

# ─── Lambdas ──────────────────────────────────────────────────────────────────

.PHONY: lambda-setup
lambda-setup: ## Cria virtualenvs e instala dependências de ambas as Lambdas
	@echo "$(CYAN)Configurando Andy...$(RESET)"
	python -m venv lambdas/andy/.venv
	lambdas/andy/.venv/bin/pip install -q -r lambdas/andy/requirements.txt
	@echo "$(CYAN)Configurando Hamm...$(RESET)"
	python -m venv lambdas/hamm/.venv
	lambdas/hamm/.venv/bin/pip install -q -r lambdas/hamm/requirements.txt
	@echo "✓ Virtualenvs prontos"

.PHONY: lambda-test
lambda-test: ## Roda os testes de ambas as Lambdas
	@echo "$(CYAN)Testando Andy...$(RESET)"
	lambdas/andy/.venv/bin/pytest lambdas/andy/tests/ -v
	@echo "$(CYAN)Testando Hamm...$(RESET)"
	lambdas/hamm/.venv/bin/pytest lambdas/hamm/tests/ -v

.PHONY: lambda-test-andy
lambda-test-andy: ## Roda apenas os testes da Lambda Andy
	lambdas/andy/.venv/bin/pytest lambdas/andy/tests/ -v

.PHONY: lambda-test-hamm
lambda-test-hamm: ## Roda apenas os testes da Lambda Hamm
	lambdas/hamm/.venv/bin/pytest lambdas/hamm/tests/ -v

.PHONY: lambda-invoke-andy
lambda-invoke-andy: ## Invoca a Lambda Andy localmente via LocalStack (requer dev-up)
	@export $$(cat dev/localstack/.env.localstack | xargs) && \
	python -c "\
import json, sys; \
sys.path.insert(0, '.'); \
from lambdas.andy.handler import lambda_handler; \
event = {'httpMethod': 'POST', 'path': '/temperature', 'body': json.dumps({'sensor_id': 'dev_sensor', 'temperature': 25.0, 'humidity': 60.0, 'heat_index': 28.0})}; \
print(json.dumps(lambda_handler(event, None), indent=2))"

.PHONY: lambda-invoke-hamm
lambda-invoke-hamm: ## Invoca a Lambda Hamm localmente via LocalStack (requer dev-up)
	@export $$(cat dev/localstack/.env.localstack | xargs) && \
	python -c "\
import json, sys; \
sys.path.insert(0, '.'); \
from lambdas.hamm.handler import lambda_handler; \
print(json.dumps(lambda_handler({}, None), indent=2))"

# ─── Infra (Terraform) ────────────────────────────────────────────────────────

.PHONY: infra-init
infra-init: ## Inicializa o Terraform
	terraform -chdir=infra init

.PHONY: infra-plan
infra-plan: ## Mostra o plano de mudanças na AWS
	terraform -chdir=infra plan

.PHONY: infra-apply
infra-apply: ## Aplica a infraestrutura na AWS
	terraform -chdir=infra apply

.PHONY: infra-destroy
infra-destroy: ## Destrói todos os recursos na AWS
	terraform -chdir=infra destroy

.PHONY: infra-outputs
infra-outputs: ## Exibe os outputs do Terraform (URLs, nomes dos recursos)
	terraform -chdir=infra output

.PHONY: infra-api-url
infra-api-url: ## Exibe a URL do endpoint POST /temperature
	@terraform -chdir=infra output -raw api_temperature_endpoint

.PHONY: infra-hamm-invoke
infra-hamm-invoke: ## Dispara manualmente o drain da fila SQS na AWS
	@FUNC=$$(terraform -chdir=infra output -raw hamm_lambda_name) && \
	echo "Invocando: $$FUNC" && \
	aws lambda invoke \
	  --function-name $$FUNC \
	  --payload '{}' \
	  --cli-binary-format raw-in-base64-out \
	  /tmp/hamm-response.json && \
	cat /tmp/hamm-response.json

# ─── Sensores ─────────────────────────────────────────────────────────────────

.PHONY: sensor-simulator
sensor-simulator: ## Roda o simulador de sensor apontando para a AWS (requer infra-apply)
	@API_URL=$$(terraform -chdir=infra output -raw api_temperature_endpoint) \
	SENSOR_ID=dev_sensor \
	SENSOR_INTERVAL=30 \
	python dev/sensor/simulator_aws.py
