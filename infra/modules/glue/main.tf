# ─── Glue Database com Federated Catalog (S3 Tables) ─────────────────────────
#
# Com S3 Tables + Iceberg, o catálogo da tabela é gerenciado pelo próprio S3 Tables.
# O Glue registra uma "federated database" que aponta para o namespace do S3 Tables.
# O Athena consulta usando: SELECT * FROM "database"."table"
#
# Vantagens:
# - Schema gerenciado automaticamente pelo Iceberg
# - Compaction automático pelo S3 Tables
# - Time Travel nativo
# - ACID transactions

# ─── Glue Catalog Database (Federated com S3 Tables) ─────────────────────────

resource "aws_glue_catalog_database" "toy_data" {
  name        = var.glue_database_name
  description = "Iceberg tables from S3 Tables — toy-data-project IoT pipeline"

  # Federated database apontando para S3 Tables
  federated_database {
    connection_name = aws_glue_connection.s3_tables.name
    identifier      = var.s3_tables_namespace
  }
}

# ─── Glue Connection para S3 Tables ──────────────────────────────────────────

resource "aws_glue_connection" "s3_tables" {
  name            = "${var.project_name}-s3-tables-connection"
  connection_type = "FEDERATED"

  connection_properties = {
    # ARN do Table Bucket no formato esperado pelo Glue
    CONNECTOR_URL = var.s3_tables_catalog_arn
  }

  physical_connection_requirements {
    availability_zone      = null
    security_group_id_list = []
    subnet_id              = null
  }
}

# ─── Glue Catalog Table (referência à tabela Iceberg no S3 Tables) ────────────
#
# Esta entrada no Glue Catalog permite que o Athena encontre a tabela
# usando a sintaxe padrão: SELECT * FROM database.table

resource "aws_glue_catalog_table" "sensor_readings" {
  name          = "sensor_readings"
  database_name = aws_glue_catalog_database.toy_data.name
  description   = "Iceberg table for raw sensor readings — managed by S3 Tables"

  table_type = "EXTERNAL_TABLE"

  # Parâmetros Iceberg
  parameters = {
    "table_type"           = "ICEBERG"
    "metadata_location"    = var.s3_tables_table_arn
    "classification"       = "iceberg"
  }

  # O schema é gerenciado pelo Iceberg — definimos apenas a estrutura base
  # O Iceberg permite schema evolution sem precisar atualizar o Glue
  storage_descriptor {
    location = var.s3_tables_table_arn

    columns {
      name    = "sensor_id"
      type    = "string"
      comment = "Unique identifier of the sensor"
    }

    columns {
      name    = "temperature"
      type    = "double"
      comment = "Temperature in Celsius (DHT22)"
    }

    columns {
      name    = "humidity"
      type    = "double"
      comment = "Relative humidity percentage (DHT22)"
    }

    columns {
      name    = "heat_index"
      type    = "double"
      comment = "Computed heat index"
    }

    columns {
      name    = "pressure"
      type    = "double"
      comment = "Atmospheric pressure in hPa (BMP280, optional)"
    }

    columns {
      name    = "altitude"
      type    = "double"
      comment = "Altitude in meters (BMP280, optional)"
    }

    columns {
      name    = "temperature_bmp"
      type    = "double"
      comment = "Temperature from BMP280 sensor (optional)"
    }

    columns {
      name    = "event_timestamp"
      type    = "bigint"
      comment = "Unix timestamp in milliseconds when the event was received"
    }

    columns {
      name    = "ingested_at"
      type    = "timestamp"
      comment = "Timestamp when the record was written to S3 Tables"
    }

    columns {
      name    = "dt"
      type    = "date"
      comment = "Partition date (YYYY-MM-DD) — Iceberg hidden partition"
    }
  }

  # Iceberg gerencia partições automaticamente
  # Não precisamos de partition_keys explícitas
}
