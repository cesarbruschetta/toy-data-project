# API

## Andy API

API to pubish menssages in Kafka topic.

## Endpoints

### GET /health-check

#### Example
```bash
$ curl --request GET \
    --url http://localhost:3000/health-check

{ "status": "OK" }
```

### POST /temperature

#### Request data 
```json
{
	"sensor_id": "teste-local",
	"temperature": 26.0,
	"humidity": 60.0	
}
```

#### Example
```bash
$ curl --request POST \
  --url http://localhost:3000/temperature \
  --header 'Content-Type: application/json' \
  --data '{
        "sensor_id":"teste-local",
        "temperature":26.0,
        "humidity":60.0	
    }'

{ "status": "OK" }
```


## Build and push docker image

```bash
$ docker build -t registry.k8s.our-cluster.ovh/toy-data-project/andy-api:latest ./andy
$ docker push registry.k8s.our-cluster.ovh/toy-data-project/andy-api:latest
```