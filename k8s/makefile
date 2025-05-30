
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

install-prometheus:  ## Install Prometheus
	@${HELM} upgrade --install prometheus prometheus \
		--repo https://prometheus-community.github.io/helm-charts \
		--create-namespace \
		--namespace prometheus \
		--version 25.25.0 \
		--values ./manifests/prometheus/values.yaml

install-grafana:  ## Install Grafana
	@${HELM} upgrade --install grafana grafana \
		--repo https://grafana.github.io/helm-charts \
		--create-namespace \
		--namespace grafana \
		--version 9.2.1 \
		--values ./manifests/grafana/values.yaml

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

install-registry-ui: ## Install Docker Registry UI
	@echo "Installing Docker Registry UI"
	@${HELM} upgrade --install docker-registry-ui \
		docker-registry-ui \
		--repo https://helm.joxit.dev \
		--namespace registry \
		--version 1.1.3 \
		--values ./manifests/docker-registry-ui/values.yaml

install-kafka: ## Install Kafka
	@echo "Installing Kafka"
	@${HELM} upgrade --install kafka \
		kafka \
		--repo https://charts.bitnami.com/bitnami \
		--namespace kafka --create-namespace \
		--version 32.2.0 \
		--values ./manifests/kafka/values.yaml

install-kafka-ui: ## Install Kafka UI
	@echo "Installing Kafka UI"
	@${HELM} upgrade --install kafka-ui \
		kafka-ui \
		--repo https://provectus.github.io/kafka-ui-charts \
		--namespace kafka \
		--version 0.5.0 \
		--values ./manifests/kafka-ui/values.yaml
	@${KUBECTL} apply -f ./manifests/kafka-ui/kafka-ui-ingress.yaml

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
	