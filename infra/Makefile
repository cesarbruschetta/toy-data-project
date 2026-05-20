.PHONY: help init fmt validate plan apply apply-auto destroy outputs api-url hamm-invoke

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Initialize Terraform and download providers
	terraform init

fmt: ## Format all Terraform files
	terraform fmt -recursive

validate: ## Validate Terraform configuration
	terraform validate

plan: ## Show what Terraform will create/change/destroy
	terraform plan

apply: ## Apply infrastructure changes
	terraform apply

apply-auto: ## Apply without confirmation prompt
	terraform apply -auto-approve

destroy: ## Destroy all provisioned resources
	terraform destroy

outputs: ## Show all Terraform outputs
	terraform output

api-url: ## Print the POST /temperature endpoint URL
	@terraform output -raw api_temperature_endpoint

hamm-invoke: ## Manually trigger the Hamm drain Lambda (requires AWS CLI)
	@FUNC=$$(terraform output -raw hamm_lambda_name) && \
	echo "Invoking: $$FUNC" && \
	aws lambda invoke \
	  --function-name $$FUNC \
	  --payload '{}' \
	  --cli-binary-format raw-in-base64-out \
	  /tmp/hamm-response.json && \
	cat /tmp/hamm-response.json
