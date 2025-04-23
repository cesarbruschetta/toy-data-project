# Consumidor

## Hamm

Consumidor de mensagens do topico do Kafka e salva os dados o MinIO.

## Configuração das Variaveis de ambiente

```bash
export MINIO_ACCESS_KEY=minio
export MINIO_SECRET_KEY=minio123
export MINIO_ENDPOINT=minio:9000
export MINIO_BUCKET=dl-test-localstack
export KAFKA_BOOTSTRAP_SERVERS=kafka:29092
export KAFKA_CONSUMER_TOPIC=toydata-topic-temperature-v1
```

## Build e push da imagem docker

```bash
$ docker build -t registry.k8s.our-cluster.ovh/toy-data-project/hamm-consumer:latest ./hamm
$ docker push registry.k8s.our-cluster.ovh/toy-data-project/hamm-consumer:latest
```