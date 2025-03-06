
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

install-cm-webhook-ovh: ## Install OVH Cloud Manager Webhook
	@echo "Installing OVH Cloud Manager Webhook"
	@${HELM} upgrade --install cm-webhook-ovh \
		cert-manager-webhook-ovh \
		--namespace cert-manager \
		--repo https://aureq.github.io/cert-manager-webhook-ovh/ \
		--version 0.7.3 \
		--values ./manifests/cm-webhook-ovh/values.yaml
	@envsubst < ./manifests/cm-webhook-ovh/ovh_api_secret.yaml | ${KUBECTL} apply -f -

install-minio: ## Install Minio
	@echo "Installing Minio"
	@${HELM} upgrade --install minio \
		minio \
		--namespace minio --create-namespace \
		--repo https://charts.min.io/ \
		--version 5.4.0 \
		--values ./manifests/minio/values.yaml \
		--set rootPassword=${MINIO_ROOT_PASSWORD} \
		--set users[0].secretKey=${MINIO_USER_SERVICE_PASSWORD}

install-registry: ## Install Docker Registry
	@echo "Installing Docker Registry"
	@${HELM} upgrade --install registry \
		docker-registry \
		--namespace registry --create-namespace \
		--repo https://helm.twun.io \
		--version 2.2.3 \
		--values ./manifests/registry/values.yaml

install-kafka: ## Install Kafka
	@echo "Installing Kafka"
	@${HELM} upgrade --install kafka \
		bitnami/kafka \
		--namespace kafka --create-namespace \
		--version 31.4.0 \
		--values ./manifests/kafka/values.yaml
