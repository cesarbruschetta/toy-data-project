"""
Hamm Lambda — scheduled SQS drain to S3.

Invocada pelo EventBridge em intervalos configuráveis (padrão: 1 hora).
A cada execução, drena TODAS as mensagens disponíveis na fila SQS e as
grava no S3 agrupadas por data de partição.

Estratégia de escrita:
- Agrupa as mensagens por dt (data do evento)
- Grava um único arquivo JSON Lines por partição por execução
  → reduz o número de PUTs no S3 e melhora a performance do Athena

Path S3: raw/toydata-topic-temperature-v1/dt=YYYY-MM-DD/<uuid>.jsonl
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

# boto3 respeita AWS_ENDPOINT_URL automaticamente — aponta para LocalStack
# quando a variável está definida, e para a AWS real quando não está.
sqs_client = boto3.client("sqs")
s3_client = boto3.client("s3")

DATA_LAKE_BUCKET = os.environ["DATA_LAKE_BUCKET"]
RAW_PREFIX = os.environ.get("RAW_PREFIX", "raw")
SQS_QUEUE_URL = os.environ["SQS_QUEUE_URL"]
SQS_BATCH_SIZE = int(os.environ.get("SQS_BATCH_SIZE", "10"))
TOPIC_NAME = "toydata-topic-temperature-v1"

# Máximo de mensagens que a Lambda tenta drenar por execução
# (evita timeout em filas muito grandes — ajuste conforme necessário)
MAX_MESSAGES_PER_RUN = 5000


def _poll_all_messages() -> list[dict]:
    """
    Drena todas as mensagens disponíveis na fila SQS.
    Retorna lista de dicts com {receipt_handle, body_parsed}.
    """
    messages = []
    empty_polls = 0

    while len(messages) < MAX_MESSAGES_PER_RUN:
        response = sqs_client.receive_message(
            QueueUrl=SQS_QUEUE_URL,
            MaxNumberOfMessages=SQS_BATCH_SIZE,  # máximo permitido pela AWS: 10
            WaitTimeSeconds=1,  # long polling curto — fila já tem mensagens acumuladas
            AttributeNames=["All"],
            MessageAttributeNames=["All"],
        )

        batch = response.get("Messages", [])
        if not batch:
            empty_polls += 1
            # Dois polls vazios consecutivos = fila drenada
            if empty_polls >= 2:
                break
            continue

        empty_polls = 0
        messages.extend(batch)

    logger.info("Polled %d messages from SQS", len(messages))
    return messages


def _parse_message(raw_message: dict) -> dict | None:
    """Parseia o body da mensagem SQS. Retorna None se inválido."""
    try:
        return json.loads(raw_message["Body"])
    except (json.JSONDecodeError, KeyError) as exc:
        logger.error(
            "Failed to parse message | messageId=%s error=%s",
            raw_message.get("MessageId"),
            exc,
        )
        return None


def _get_partition_date(payload: dict) -> str:
    """Determina a data de partição a partir do timestamp do evento."""
    event_timestamp_ms = payload.get("timestamp")
    if event_timestamp_ms:
        try:
            event_dt = datetime.fromtimestamp(event_timestamp_ms / 1000, tz=timezone.utc)
            return event_dt.strftime("%Y-%m-%d")
        except (ValueError, OSError, OverflowError):
            pass
    return datetime.now(tz=timezone.utc).strftime("%Y-%m-%d")


def _write_partition_to_s3(dt: str, records: list[dict]) -> str:
    """
    Grava um arquivo JSON Lines no S3 para uma partição específica.
    Retorna o S3 key gravado.
    """
    ingested_at = datetime.now(tz=timezone.utc).isoformat()
    run_id = str(uuid.uuid4())

    # Enriquece cada registro com metadados de ingestão
    enriched_records = [
        {**record, "ingested_at": ingested_at}
        for record in records
    ]

    # JSON Lines: um JSON por linha — formato ideal para Athena/Glue
    content = "\n".join(json.dumps(r, ensure_ascii=False) for r in enriched_records)

    s3_key = f"{RAW_PREFIX}/{TOPIC_NAME}/dt={dt}/{run_id}.jsonl"

    s3_client.put_object(
        Bucket=DATA_LAKE_BUCKET,
        Key=s3_key,
        Body=content.encode("utf-8"),
        ContentType="application/x-ndjson",
        Metadata={
            "partition-date": dt,
            "record-count": str(len(records)),
            "run-id": run_id,
        },
    )

    logger.info(
        "Written to S3 | key=%s records=%d dt=%s",
        s3_key,
        len(records),
        dt,
    )
    return s3_key


def _delete_messages(messages: list[dict]) -> None:
    """Deleta mensagens da SQS em batches de 10 (limite da API)."""
    for i in range(0, len(messages), 10):
        batch = messages[i : i + 10]
        entries = [
            {"Id": str(idx), "ReceiptHandle": msg["ReceiptHandle"]}
            for idx, msg in enumerate(batch)
        ]
        try:
            response = sqs_client.delete_message_batch(
                QueueUrl=SQS_QUEUE_URL,
                Entries=entries,
            )
            failed = response.get("Failed", [])
            if failed:
                logger.warning("Failed to delete %d messages from SQS: %s", len(failed), failed)
        except ClientError as exc:
            logger.error("Error deleting SQS batch: %s", exc)


def lambda_handler(event: dict, context) -> dict:
    """
    Entry point — invocado pelo EventBridge no schedule configurado.
    O `event` do EventBridge é ignorado; a Lambda sempre drena a fila completa.
    """
    logger.info(
        "Hamm drain started | queue=%s bucket=%s",
        SQS_QUEUE_URL,
        DATA_LAKE_BUCKET,
    )

    # 1. Drena todas as mensagens da fila
    raw_messages = _poll_all_messages()

    if not raw_messages:
        logger.info("Queue is empty — nothing to process")
        return {"status": "empty", "processed": 0}

    # 2. Parseia e agrupa por data de partição
    partitions: dict[str, list[dict]] = defaultdict(list)
    valid_messages = []

    for raw_msg in raw_messages:
        payload = _parse_message(raw_msg)
        if payload is None:
            # Mensagem inválida — deleta da fila para não bloquear
            _delete_messages([raw_msg])
            continue

        dt = _get_partition_date(payload)
        partitions[dt].append(payload)
        valid_messages.append(raw_msg)

    logger.info(
        "Grouped %d records into %d partitions: %s",
        len(valid_messages),
        len(partitions),
        sorted(partitions.keys()),
    )

    # 3. Grava no S3 — um arquivo por partição por execução
    s3_keys = []
    write_errors = []

    for dt, records in partitions.items():
        try:
            key = _write_partition_to_s3(dt, records)
            s3_keys.append(key)
        except ClientError as exc:
            logger.error("Failed to write partition dt=%s to S3: %s", dt, exc)
            write_errors.append(dt)

    # 4. Deleta da SQS apenas as mensagens gravadas com sucesso
    if write_errors:
        # Se alguma partição falhou, não deleta as mensagens daquela data
        failed_dates = set(write_errors)
        messages_to_delete = [
            msg for msg, raw in zip(valid_messages, raw_messages)
            if _get_partition_date(_parse_message(raw) or {}) not in failed_dates
        ]
        logger.warning(
            "Partial failure — keeping %d messages in queue for retry",
            len(valid_messages) - len(messages_to_delete),
        )
    else:
        messages_to_delete = valid_messages

    _delete_messages(messages_to_delete)

    result = {
        "status": "ok" if not write_errors else "partial",
        "processed": len(valid_messages),
        "s3_files_written": len(s3_keys),
        "partitions": sorted(partitions.keys()),
        "failed_partitions": write_errors,
    }

    logger.info("Hamm drain completed | %s", result)
    return result
