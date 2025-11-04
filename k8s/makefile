
.DEFAULT_GOAL := help 

# SET .env and override default envs
ifneq (,$(wildcard ./.env))
    include .env
	export $(shell sed 's/=.*//' .env)
endif

help: ## Show this help
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?# "}; {printf "\033[36m%-40s\033[0m %s\n", $$1, $$2}'


KUBECTL := kubectl --kubeconfig=$(KUBE_CONFIG)
HELM := helm --kubeconfig=$(KUBE_CONFIG)

install-andyApi: ## Install Andy API
	@echo "Installing Andy API"
	@${KUBECTL} apply \
		-f ./manifests/andy-api/

install-hammConsumer: ## Install Hamm Consumer
	@echo "Installing Hamm Consumer"
	@${KUBECTL} delete secret hamm-consumer \
		--namespace toy-data-project \
		--ignore-not-found
	@${KUBECTL} create secret generic \
		hamm-consumer \
		--namespace toy-data-project \
		--from-literal=minio_secret_key=${MINIO_USER_SERVICE_PASSWORD}
	@${KUBECTL} apply \
		-f ./manifests/hamm-consumer/
	