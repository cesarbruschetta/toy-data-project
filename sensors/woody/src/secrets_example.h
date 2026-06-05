#ifndef SECRETS_H
#define SECRETS_H

// Wi-Fi
const char* WIFI_SSID     = "";
const char* WIFI_PASSWORD = "";

// Identificador único deste sensor — aparece no campo sensor_id dos dados
const char* SENSOR_ID = "woody";

// Endpoint do API Gateway AWS
// Obtenha após o terraform apply: make infra-api-url
// Se tiver custom domain configurado: https://andy-api.aws.our-cluster.ovh/temperature
const char* ANDY_API = "https://<id>.execute-api.us-east-1.amazonaws.com/v1/temperature";

#endif
