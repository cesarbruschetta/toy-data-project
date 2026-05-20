"""
Andy Lambda — IoT sensor data ingestion.

Receives HTTP POST /temperature from API Gateway,
validates the payload and publishes to SNS.
"""

import json
import logging
import os
import time
import uuid

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# boto3 respeita AWS_ENDPOINT_URL automaticamente — aponta para LocalStack
# quando a variável está definida, e para a AWS real quando não está.
sns_client = boto3.client("sns")

SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]

REQUIRED_FIELDS = {"sensor_id", "temperature", "humidity", "heat_index"}
NUMERIC_FIELDS = {"temperature", "humidity", "heat_index", "pressure", "altitude", "temperature_bmp"}


def _response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "X-Request-Id": str(uuid.uuid4()),
        },
        "body": json.dumps(body),
    }


def _validate_payload(payload: dict) -> list[str]:
    """Returns a list of validation error messages."""
    errors = []

    missing = REQUIRED_FIELDS - payload.keys()
    if missing:
        errors.append(f"Missing required fields: {sorted(missing)}")

    for field in NUMERIC_FIELDS:
        if field in payload and not isinstance(payload[field], (int, float)):
            errors.append(f"Field '{field}' must be a number, got {type(payload[field]).__name__}")

    if "sensor_id" in payload and not isinstance(payload["sensor_id"], str):
        errors.append("Field 'sensor_id' must be a string")

    return errors


def lambda_handler(event: dict, context) -> dict:
    http_method = event.get("httpMethod", "")
    path = event.get("path", "")

    # ── Health check ──────────────────────────────────────────────────────────
    if http_method == "GET" and path == "/health-check":
        return _response(200, {"ping": "OK"})

    # ── POST /temperature ─────────────────────────────────────────────────────
    if http_method == "POST" and path == "/temperature":
        raw_body = event.get("body", "")
        if not raw_body:
            return _response(400, {"error": "Request body is required"})

        try:
            payload = json.loads(raw_body)
        except json.JSONDecodeError as exc:
            logger.warning("Invalid JSON body: %s", exc)
            return _response(400, {"error": "Invalid JSON body"})

        errors = _validate_payload(payload)
        if errors:
            logger.warning("Payload validation failed: %s", errors)
            return _response(422, {"error": "Validation failed", "details": errors})

        # Adiciona timestamp de ingestão
        message = {
            **payload,
            "timestamp": int(time.time() * 1000),  # milissegundos, compatível com o schema original
        }

        message_id = str(uuid.uuid4())

        try:
            sns_client.publish(
                TopicArn=SNS_TOPIC_ARN,
                Message=json.dumps(message),
                MessageAttributes={
                    "sensor_id": {
                        "DataType": "String",
                        "StringValue": payload["sensor_id"],
                    },
                },
            )
        except ClientError as exc:
            logger.error("Failed to publish to SNS: %s", exc)
            return _response(500, {"error": "Failed to process message"})

        logger.info(
            "Published message | sensor_id=%s message_id=%s",
            payload["sensor_id"],
            message_id,
        )
        return _response(200, {"status": "OK", "message_id": message_id})

    # ── 404 para qualquer outra rota ──────────────────────────────────────────
    return _response(404, {"error": f"Route {http_method} {path} not found"})
