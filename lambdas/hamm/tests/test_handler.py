"""
Tests for Hamm Lambda handler.
Uses moto to mock SQS and S3 — no real AWS calls are made.
"""

import importlib
import json
import os

import boto3
import pytest
from moto import mock_aws

BUCKET_NAME = "toy-data-project-data-lake"
QUEUE_NAME = "toy-data-project-temperature-queue"

os.environ.setdefault("DATA_LAKE_BUCKET", BUCKET_NAME)
os.environ.setdefault("RAW_PREFIX", "raw")
os.environ.setdefault("SQS_QUEUE_URL", f"https://sqs.us-east-1.amazonaws.com/123456789012/{QUEUE_NAME}")
os.environ.setdefault("SQS_BATCH_SIZE", "10")
os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")
os.environ.setdefault("AWS_ACCESS_KEY_ID", "test")
os.environ.setdefault("AWS_SECRET_ACCESS_KEY", "test")


def _make_message(sensor_id: str = "buzz", timestamp: int = 1700000000000) -> dict:
    return {
        "sensor_id": sensor_id,
        "temperature": 24.5,
        "humidity": 65.0,
        "heat_index": 27.75,
        "timestamp": timestamp,
    }


@pytest.fixture()
def aws_resources():
    """Creates mock S3 bucket and SQS queue, reloads handler to pick up fresh clients."""
    with mock_aws():
        s3 = boto3.client("s3", region_name="us-east-1")
        s3.create_bucket(Bucket=BUCKET_NAME)

        sqs = boto3.client("sqs", region_name="us-east-1")
        queue = sqs.create_queue(QueueName=QUEUE_NAME)
        queue_url = queue["QueueUrl"]

        os.environ["SQS_QUEUE_URL"] = queue_url

        import hamm.handler as mod
        importlib.reload(mod)

        yield {"s3": s3, "sqs": sqs, "queue_url": queue_url}


def _enqueue(sqs_client, queue_url: str, payload: dict) -> None:
    sqs_client.send_message(QueueUrl=queue_url, MessageBody=json.dumps(payload))


class TestEmptyQueue:
    def test_empty_queue_returns_empty_status(self, aws_resources):
        from hamm.handler import lambda_handler
        result = lambda_handler({}, None)
        assert result["status"] == "empty"
        assert result["processed"] == 0


class TestDrainAndWrite:
    def test_single_message_written_to_s3(self, aws_resources):
        sqs, s3, queue_url = aws_resources["sqs"], aws_resources["s3"], aws_resources["queue_url"]
        _enqueue(sqs, queue_url, _make_message())

        from hamm.handler import lambda_handler
        result = lambda_handler({}, None)

        assert result["status"] == "ok"
        assert result["processed"] == 1
        assert result["s3_files_written"] == 1
        assert s3.list_objects_v2(Bucket=BUCKET_NAME, Prefix="raw/")["KeyCount"] == 1

    def test_messages_grouped_by_partition_date(self, aws_resources):
        sqs, queue_url = aws_resources["sqs"], aws_resources["queue_url"]
        _enqueue(sqs, queue_url, _make_message(timestamp=1700000000000))  # 2023-11-14
        _enqueue(sqs, queue_url, _make_message(timestamp=1701000000000))  # 2023-11-26

        from hamm.handler import lambda_handler
        result = lambda_handler({}, None)

        assert result["processed"] == 2
        assert result["s3_files_written"] == 2
        assert len(result["partitions"]) == 2

    def test_multiple_messages_same_date_one_file(self, aws_resources):
        sqs, s3, queue_url = aws_resources["sqs"], aws_resources["s3"], aws_resources["queue_url"]
        for i in range(5):
            _enqueue(sqs, queue_url, _make_message(sensor_id=f"sensor_{i}", timestamp=1700000000000))

        from hamm.handler import lambda_handler
        result = lambda_handler({}, None)

        assert result["processed"] == 5
        assert result["s3_files_written"] == 1

        # Arquivo deve ter 5 linhas JSON Lines
        key = s3.list_objects_v2(Bucket=BUCKET_NAME, Prefix="raw/")["Contents"][0]["Key"]
        body = s3.get_object(Bucket=BUCKET_NAME, Key=key)["Body"].read().decode()
        lines = [l for l in body.strip().split("\n") if l]
        assert len(lines) == 5

    def test_queue_is_empty_after_drain(self, aws_resources):
        sqs, queue_url = aws_resources["sqs"], aws_resources["queue_url"]
        _enqueue(sqs, queue_url, _make_message())

        from hamm.handler import lambda_handler
        lambda_handler({}, None)

        attrs = sqs.get_queue_attributes(
            QueueUrl=queue_url,
            AttributeNames=["ApproximateNumberOfMessages"],
        )
        assert attrs["Attributes"]["ApproximateNumberOfMessages"] == "0"

    def test_s3_key_follows_partition_pattern(self, aws_resources):
        sqs, s3, queue_url = aws_resources["sqs"], aws_resources["s3"], aws_resources["queue_url"]
        _enqueue(sqs, queue_url, _make_message(timestamp=1700000000000))

        from hamm.handler import lambda_handler
        lambda_handler({}, None)

        key = s3.list_objects_v2(Bucket=BUCKET_NAME, Prefix="raw/")["Contents"][0]["Key"]
        # raw/<topic>/dt=YYYY-MM-DD/<uuid>.jsonl
        assert key.startswith("raw/toydata-topic-temperature-v1/dt=")
        assert key.endswith(".jsonl")

    def test_ingested_at_field_added(self, aws_resources):
        sqs, s3, queue_url = aws_resources["sqs"], aws_resources["s3"], aws_resources["queue_url"]
        _enqueue(sqs, queue_url, _make_message())

        from hamm.handler import lambda_handler
        lambda_handler({}, None)

        key = s3.list_objects_v2(Bucket=BUCKET_NAME, Prefix="raw/")["Contents"][0]["Key"]
        body = s3.get_object(Bucket=BUCKET_NAME, Key=key)["Body"].read().decode()
        record = json.loads(body.strip().split("\n")[0])
        assert "ingested_at" in record


class TestInvalidMessages:
    def test_invalid_json_message_is_discarded(self, aws_resources):
        sqs, queue_url = aws_resources["sqs"], aws_resources["queue_url"]
        sqs.send_message(QueueUrl=queue_url, MessageBody="not-valid-json")

        from hamm.handler import lambda_handler
        result = lambda_handler({}, None)

        assert result["processed"] == 0
