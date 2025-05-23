# Kubernetes

Manifests and scripts to deploy services on Kubernetes.

## Commands

```bash
help                                     Show this help
install-cm-webhook-ovh                   Install OVH Cloud Manager Webhook
install-minio                            Install Minio
install-registry                         Install Docker Registry
install-registry-ui                      Install Docker Registry UI
install-kafka:                           Install Kafka
install-kafka-ui                         Install Kafka UI
install-andyApi                          Install Andy API
install-hammConsumer                     Install Hamm Consumer
```

## Environment
- `KUBE_CONFIG`: Path to the Kubernetes config file. Default is `~/.kube/config`.
- `MINIO_ROOT_PASSWORD`: Minio root password.
- `MINIO_USER_SERVICE_PASSWORD`: Minio user service password.
- `OVH_APP_KEY`: OVH application key. Encode in base64.
- `OVH_APP_SECRET`: OVH application secret. Encode in base64.
- `OVH_CONSUMER_KEY`: OVH consumer key. Encode in base64.

## References

- [OVH Webhook for Cert Manager](https://aureq.github.io/cert-manager-webhook-ovh/)
- [Docker Registry](https://artifacthub.io/packages/helm/twuni/docker-registry)
- [MinIO Community](https://github.com/minio/minio/tree/master/helm/minio)
- [Apache Kafka](https://github.com/bitnami/charts/tree/main/bitnami/kafka)
- [UI for Apache Kafka](https://docs.kafka-ui.provectus.io/)
- [Docker Registry UI Chart](https://helm.joxit.dev/charts/docker-registry-ui/)
