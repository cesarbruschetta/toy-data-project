"""
Hamm Lambda — scheduled SQS drain to S3 data lake (JSON Lines).

Invocada pelo EventBridge em intervalos configuráveis (padrão: 1 hora).
Drena todas as mensagens da fila SQS, agrupa por data de partição e grava
um arquivo JSON Lines por partição por execução no S3.

Path: raw/<topic>/dt=YYYY-MM-DD/<uuid>.jsonl
"""

import json
import logging
import os
import uuid
from collections import defaultdict
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sqs_client = boto3.client("sqs")
s3_client = boto3.client("s3")

DATA_LAKE_BUCKET = os.environ["DATA_LAKE_BUCKET"]
RAW_PREFIX = os.environ.get("RAW_PREFIX", "raw")
TOPIC_PREFIX = "toydata-topic-temperature-v1"
SQS_QUEUE_URL = os.environ["SQS_QUEUE_URL"]
SQS_BATCH_SIZE = int(os.environ.get("SQS_BATCH_SIZE", "10"))
MAX_MESSAGES_PER_RUN = 5000


def _poll_all_messages() -> list[dict]:
    messages = []
    empty_polls = 0
    while len(messages) < MAX_MESSAGES_PER_RUN:
        response = sqs_client.receive_message(
            QueueUrl=SQS_QUEUE_URL,
            MaxNumberOfMessages=SQS_BATCH_SIZE,
            WaitTimeSeconds=1,
        )
        batch = response.get("Messages", [])
        if not batch:
            empty_polls += 1
            if empty_polls >= 2:
                break
            continue
        empty_polls = 0
        messages.extend(batch)
    logger.info("Polled %d messages from SQS", len(messages))
    return messages


def _partition_date(payload: dict) -> str:
    ts_ms = payload.get("timestamp")
    if ts_ms:
        try:
            return datetime.fromtimestamp(ts_ms / 1000, tz=timezone.utc).strftime("%Y-%m-%d")
        except (ValueError, OSError, OverflowError):
            pass
    return datetime.now(tz=timezone.utc).strftime("%Y-%m-%d")


def _delete_messages(messages: list[dict]) -> None:
    for i in range(0, len(messages), 10):
        batch = messages[i : i + 10]
        entries = [
            {"Id": str(idx), "ReceiptHandle": msg["ReceiptHandle"]}
            for idx, msg in enumerate(batch)
        ]
        try:
            resp = sqs_client.delete_message_batch(QueueUrl=SQS_QUEUE_URL, Entries=entries)
            if resp.get("Failed"):
                logger.warning("Failed to delete %d messages", len(resp["Failed"]))
        except ClientError as exc:
            logger.error("Error deleting SQS batch: %s", exc)


def lambda_handler(event: dict, context) -> dict:
    logger.info("Hamm drain started | queue=%s bucket=%s", SQS_QUEUE_URL, DATA_LAKE_BUCKET)

    raw_messages = _poll_all_messages()
    if not raw_messages:
        logger.info("Queue is empty — nothing to process")
        return {"status": "empty", "processed": 0}

    ingested_at = datetime.now(tz=timezone.utc).isoformat()
    partitions: dict[str, list[dict]] = defaultdict(list)
    valid_messages = []

    for raw_msg in raw_messages:
        try:
            payload = json.loads(raw_msg["Body"])
        except (json.JSONDecodeError, KeyError) as exc:
            logger.error("Invalid message %s: %s", raw_msg.get("MessageId"), exc)
            _delete_messages([raw_msg])
            continue

        payload["ingested_at"] = ingested_at
        partitions[_partition_date(payload)].append(payload)
        valid_messages.append(raw_msg)

    if not valid_messages:
        return {"status": "empty", "processed": 0}

    files_written = []
    for dt, records in partitions.items():
        key = f"{RAW_PREFIX}/{TOPIC_PREFIX}/dt={dt}/{uuid.uuid4()}.jsonl"
        body = "\n".join(json.dumps(r) for r in records)
        s3_client.put_object(
            Bucket=DATA_LAKE_BUCKET,
            Key=key,
            Body=body.encode(),
            ContentType="application/x-ndjson",
        )
        files_written.append(key)
        logger.info("Wrote %d records to s3://%s/%s", len(records), DATA_LAKE_BUCKET, key)

    _delete_messages(valid_messages)

    result = {
        "status": "ok",
        "processed": len(valid_messages),
        "s3_files_written": len(files_written),
        "partitions": list(partitions.keys()),
    }
    logger.info("Hamm drain completed | %s", result)
    return result
