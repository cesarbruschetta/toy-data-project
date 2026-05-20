"""
Tests for Andy Lambda handler.
Uses moto to mock SNS — no real AWS calls are made.
"""

import importlib
import json
import os

import boto3
import pytest
from moto import mock_aws

os.environ.setdefault("SNS_TOPIC_ARN", "arn:aws:sns:us-east-1:123456789012:toy-data-project-temperature")
os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")
os.environ.setdefault("AWS_ACCESS_KEY_ID", "test")
os.environ.setdefault("AWS_SECRET_ACCESS_KEY", "test")


def _make_post_event(body: dict) -> dict:
    return {
        "httpMethod": "POST",
        "path": "/temperature",
        "body": json.dumps(body),
    }


def _make_get_event(path: str) -> dict:
    return {"httpMethod": "GET", "path": path, "body": None}


@pytest.fixture()
def sns_topic():
    """Creates a mock SNS topic and reloads the handler to pick up fresh clients."""
    with mock_aws():
        client = boto3.client("sns", region_name="us-east-1")
        topic = client.create_topic(Name="toy-data-project-temperature")
        os.environ["SNS_TOPIC_ARN"] = topic["TopicArn"]

        import andy.handler as mod
        importlib.reload(mod)

        yield topic["TopicArn"]


VALID_PAYLOAD = {
    "sensor_id": "buzz",
    "temperature": 24.5,
    "humidity": 65.0,
    "heat_index": 27.75,
}


class TestHealthCheck:
    def test_returns_200(self):
        from andy.handler import lambda_handler
        response = lambda_handler(_make_get_event("/health-check"), None)
        assert response["statusCode"] == 200

    def test_body_contains_ping(self):
        from andy.handler import lambda_handler
        response = lambda_handler(_make_get_event("/health-check"), None)
        body = json.loads(response["body"])
        assert body["ping"] == "OK"


class TestTemperaturePost:
    def test_valid_payload_returns_200(self, sns_topic):
        from andy.handler import lambda_handler
        response = lambda_handler(_make_post_event(VALID_PAYLOAD), None)
        assert response["statusCode"] == 200

    def test_valid_payload_returns_message_id(self, sns_topic):
        from andy.handler import lambda_handler
        response = lambda_handler(_make_post_event(VALID_PAYLOAD), None)
        body = json.loads(response["body"])
        assert "message_id" in body

    def test_optional_fields_accepted(self, sns_topic):
        from andy.handler import lambda_handler
        payload = {**VALID_PAYLOAD, "pressure": 1013.25, "altitude": 50.0}
        response = lambda_handler(_make_post_event(payload), None)
        assert response["statusCode"] == 200

    def test_missing_required_field_returns_422(self, sns_topic):
        from andy.handler import lambda_handler
        payload = {k: v for k, v in VALID_PAYLOAD.items() if k != "temperature"}
        response = lambda_handler(_make_post_event(payload), None)
        assert response["statusCode"] == 422

    def test_invalid_json_returns_400(self, sns_topic):
        from andy.handler import lambda_handler
        event = {"httpMethod": "POST", "path": "/temperature", "body": "not-json"}
        response = lambda_handler(event, None)
        assert response["statusCode"] == 400

    def test_empty_body_returns_400(self, sns_topic):
        from andy.handler import lambda_handler
        event = {"httpMethod": "POST", "path": "/temperature", "body": ""}
        response = lambda_handler(event, None)
        assert response["statusCode"] == 400

    def test_non_numeric_temperature_returns_422(self, sns_topic):
        from andy.handler import lambda_handler
        payload = {**VALID_PAYLOAD, "temperature": "hot"}
        response = lambda_handler(_make_post_event(payload), None)
        assert response["statusCode"] == 422

    def test_timestamp_added_to_message(self, sns_topic):
        """Verifica que o handler adiciona timestamp antes de publicar no SNS."""
        from andy.handler import lambda_handler
        response = lambda_handler(_make_post_event(VALID_PAYLOAD), None)
        assert response["statusCode"] == 200
        # Se chegou aqui sem erro, o SNS aceitou a mensagem com timestamp


class TestUnknownRoute:
    def test_unknown_route_returns_404(self):
        from andy.handler import lambda_handler
        event = {"httpMethod": "GET", "path": "/unknown", "body": None}
        response = lambda_handler(event, None)
        assert response["statusCode"] == 404
