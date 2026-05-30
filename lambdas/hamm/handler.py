"""
Hamm Lambda — scheduled SQS drain to Iceberg (S3 Tables).

Invocada pelo EventBridge em intervalos configuráveis (padrão: 1 hora).
A cada execução, drena TODAS as mensagens disponíveis na fila SQS e as
grava na tabela Iceberg no S3 Tables.

Arquitetura:
- Usa PyIceberg para escrever diretamente na tabela Iceberg
- S3 Tables gerencia compaction, snapshots e metadata automaticamente
- Particionamento por data (dt) é feito pelo Iceberg hidden partitioning

Vantagens sobre JSON Lines:
- Compressão Parquet (~10x menor)
- Predicate pushdown (queries mais rápidas e baratas)
- Schema evolution nativo
- Time travel (queries históricas)
- ACID transactions
"""

import json
import logging
import os
from collections import defaultdict
from datetime import datetime, timezone, date

import boto3
import pyarrow as pa
from pyiceberg.catalog import load_catalog
from pyiceberg.exceptions import NoSuchTableError
from pyiceberg.schema import Schema
from pyiceberg.types import (
    StringType, DoubleType, LongType, TimestampType, DateType, NestedField
)
from pyiceberg.partitioning import PartitionSpec, PartitionField
from pyiceberg.transforms import DayTransform
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# boto3 clients
sqs_client = boto3.client("sqs")

# ─── Environment Variables ────────────────────────────────────────────────────

S3_TABLES_ARN = os.environ["S3_TABLES_ARN"]
S3_TABLES_NAMESPACE = os.environ.get("S3_TABLES_NAMESPACE", "raw")
S3_TABLES_TABLE = os.environ.get("S3_TABLES_TABLE", "sensor_readings")
SQS_QUEUE_URL = os.environ["SQS_QUEUE_URL"]
SQS_BATCH_SIZE = int(os.environ.get("SQS_BATCH_SIZE", "10"))

# Máximo de mensagens por execução (evita timeout)
MAX_MESSAGES_PER_RUN = 5000

# ─── Iceberg Schema ───────────────────────────────────────────────────────────

ICEBERG_SCHEMA = Schema(
    NestedField(field_id=1, name="sensor_id", field_type=StringType(), required=True),
    NestedField(field_id=2, name="temperature", field_type=DoubleType(), required=True),
    NestedField(field_id=3, name="humidity", field_type=DoubleType(), required=True),
    NestedField(field_id=4, name="heat_index", field_type=DoubleType(), required=True),
    NestedField(field_id=5, name="pressure", field_type=DoubleType(), required=False),
    NestedField(field_id=6, name="altitude", field_type=DoubleType(), required=False),
    NestedField(field_id=7, name="temperature_bmp", field_type=DoubleType(), required=False),
    NestedField(field_id=8, name="event_timestamp", field_type=LongType(), required=True),
    NestedField(field_id=9, name="ingested_at", field_type=TimestampType(), required=True),
    NestedField(field_id=10, name="dt", field_type=DateType(), required=True),
)

# Particionamento por data (hidden partitioning)
PARTITION_SPEC = PartitionSpec(
    PartitionField(source_id=10, field_id=1000, transform=DayTransform(), name="dt_day")
)


def _get_iceberg_catalog():
    """
    Carrega o catálogo Iceberg apontando para S3 Tables.
    """
    return load_catalog(
        name="s3tables",
        **{
            "type": "s3tables",
            "s3tables.catalog-arn": S3_TABLES_ARN,
        }
    )


def _get_or_create_table(catalog):
    """
    Obtém a tabela Iceberg ou cria se não existir.
    """
    table_identifier = f"{S3_TABLES_NAMESPACE}.{S3_TABLES_TABLE}"
    
    try:
        return catalog.load_table(table_identifier)
    except NoSuchTableError:
        logger.info("Table %s not found, creating...", table_identifier)
        return catalog.create_table(
            identifier=table_identifier,
            schema=ICEBERG_SCHEMA,
            partition_spec=PARTITION_SPEC,
        )


def _poll_all_messages() -> list[dict]:
    """
    Drena todas as mensagens disponíveis na fila SQS.
    """
    messages = []
    empty_polls = 0

    while len(messages) < MAX_MESSAGES_PER_RUN:
        response = sqs_client.receive_message(
            QueueUrl=SQS_QUEUE_URL,
            MaxNumberOfMessages=SQS_BATCH_SIZE,
            WaitTimeSeconds=1,
            AttributeNames=["All"],
            MessageAttributeNames=["All"],
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


def _parse_message(raw_message: dict) -> dict | None:
    """Parseia o body da mensagem SQS."""
    try:
        return json.loads(raw_message["Body"])
    except (json.JSONDecodeError, KeyError) as exc:
        logger.error(
            "Failed to parse message | messageId=%s error=%s",
            raw_message.get("MessageId"),
            exc,
        )
        return None


def _get_partition_date(payload: dict) -> date:
    """Determina a data de partição a partir do timestamp do evento."""
    event_timestamp_ms = payload.get("timestamp")
    if event_timestamp_ms:
        try:
            event_dt = datetime.fromtimestamp(event_timestamp_ms / 1000, tz=timezone.utc)
            return event_dt.date()
        except (ValueError, OSError, OverflowError):
            pass
    return datetime.now(tz=timezone.utc).date()


def _records_to_arrow(records: list[dict]) -> pa.Table:
    """
    Converte lista de dicts para PyArrow Table.
    """
    ingested_at = datetime.now(tz=timezone.utc)
    
    # Prepara as colunas
    sensor_ids = []
    temperatures = []
    humidities = []
    heat_indices = []
    pressures = []
    altitudes = []
    temperature_bmps = []
    event_timestamps = []
    ingested_ats = []
    dts = []

    for record in records:
        sensor_ids.append(record["sensor_id"])
        temperatures.append(float(record["temperature"]))
        humidities.append(float(record["humidity"]))
        heat_indices.append(float(record["heat_index"]))
        pressures.append(record.get("pressure"))  # pode ser None
        altitudes.append(record.get("altitude"))
        temperature_bmps.append(record.get("temperature_bmp"))
        event_timestamps.append(record.get("timestamp", int(ingested_at.timestamp() * 1000)))
        ingested_ats.append(ingested_at)
        dts.append(_get_partition_date(record))

    # Cria a tabela PyArrow
    return pa.table({
        "sensor_id": pa.array(sensor_ids, type=pa.string()),
        "temperature": pa.array(temperatures, type=pa.float64()),
        "humidity": pa.array(humidities, type=pa.float64()),
        "heat_index": pa.array(heat_indices, type=pa.float64()),
        "pressure": pa.array(pressures, type=pa.float64()),
        "altitude": pa.array(altitudes, type=pa.float64()),
        "temperature_bmp": pa.array(temperature_bmps, type=pa.float64()),
        "event_timestamp": pa.array(event_timestamps, type=pa.int64()),
        "ingested_at": pa.array(ingested_ats, type=pa.timestamp("us", tz="UTC")),
        "dt": pa.array(dts, type=pa.date32()),
    })


def _delete_messages(messages: list[dict]) -> None:
    """Deleta mensagens da SQS em batches de 10."""
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
                logger.warning("Failed to delete %d messages: %s", len(failed), failed)
        except ClientError as exc:
            logger.error("Error deleting SQS batch: %s", exc)


def lambda_handler(event: dict, context) -> dict:
    """
    Entry point — invocado pelo EventBridge.
    Drena a fila SQS e grava na tabela Iceberg.
    """
    logger.info(
        "Hamm drain started | queue=%s table=%s.%s",
        SQS_QUEUE_URL,
        S3_TABLES_NAMESPACE,
        S3_TABLES_TABLE,
    )

    # 1. Drena todas as mensagens da fila
    raw_messages = _poll_all_messages()

    if not raw_messages:
        logger.info("Queue is empty — nothing to process")
        return {"status": "empty", "processed": 0}

    # 2. Parseia as mensagens
    valid_records = []
    valid_messages = []

    for raw_msg in raw_messages:
        payload = _parse_message(raw_msg)
        if payload is None:
            # Mensagem inválida — deleta para não bloquear
            _delete_messages([raw_msg])
            continue

        valid_records.append(payload)
        valid_messages.append(raw_msg)

    if not valid_records:
        logger.info("No valid records to process")
        return {"status": "empty", "processed": 0}

    # 3. Converte para PyArrow Table
    arrow_table = _records_to_arrow(valid_records)
    
    logger.info(
        "Prepared %d records for Iceberg write | partitions=%s",
        len(valid_records),
        sorted(set(str(d) for d in arrow_table["dt"].to_pylist())),
    )

    # 4. Carrega o catálogo e a tabela Iceberg
    try:
        catalog = _get_iceberg_catalog()
        table = _get_or_create_table(catalog)
        
        # 5. Append dos dados na tabela Iceberg
        table.append(arrow_table)
        
        logger.info(
            "Successfully wrote %d records to Iceberg table",
            len(valid_records),
        )
        
    except Exception as exc:
        logger.error("Failed to write to Iceberg: %s", exc)
        # Não deleta as mensagens — ficarão para retry
        return {
            "status": "error",
            "error": str(exc),
            "processed": 0,
        }

    # 6. Deleta as mensagens processadas da SQS
    _delete_messages(valid_messages)

    result = {
        "status": "ok",
        "processed": len(valid_records),
        "snapshot_id": str(table.current_snapshot().snapshot_id) if table.current_snapshot() else None,
    }

    logger.info("Hamm drain completed | %s", result)
    return result
