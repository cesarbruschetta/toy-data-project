locals {
  s3_raw_path = "s3://${var.data_lake_bucket}/${var.raw_prefix}/${var.topic_name}/"

  # Data de início para o Partition Projection — ajuste conforme necessário
  projection_start_date = "2025-01-01"
}

# ─── Glue Database ────────────────────────────────────────────────────────────

resource "aws_glue_catalog_database" "toy_data" {
  name        = var.glue_database_name
  description = "Raw sensor data from toy-data-project IoT pipeline"

  location_uri = "s3://${var.data_lake_bucket}/${var.raw_prefix}/"
}

# ─── Glue Table com Partition Projection ─────────────────────────────────────
#
# Partition Projection elimina a necessidade do Glue Crawler.
# O Athena calcula as partições diretamente a partir do range de datas,
# sem precisar consultar o Glue Catalog para cada nova data.
#
# Path no S3: raw/<topic>/dt=YYYY-MM-DD/<arquivo>.jsonl

resource "aws_glue_catalog_table" "sensor_readings" {
  name          = "sensor_readings"
  database_name = aws_glue_catalog_database.toy_data.name
  description   = "Raw sensor readings — partitioned by date via Partition Projection"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"              = "json"
    "compressionType"             = "none"
    "typeOfData"                  = "file"
    "EXTERNAL"                    = "TRUE"

    # ── Partition Projection ─────────────────────────────────────────────────
    "projection.enabled"          = "true"
    "projection.dt.type"          = "date"
    "projection.dt.format"        = "yyyy-MM-dd"
    "projection.dt.range"         = "${local.projection_start_date},NOW"
    "projection.dt.interval"      = "1"
    "projection.dt.interval.unit" = "DAYS"

    # Template do path S3 para cada partição
    "storage.location.template"   = "${local.s3_raw_path}dt=$${dt}/"
  }

  storage_descriptor {
    location      = local.s3_raw_path
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "JsonSerDe"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      parameters = {
        "serialization.format"  = "1"
        "ignore.malformed.json" = "TRUE"
      }
    }

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
      comment = "Unix timestamp in milliseconds when the event was received by Andy API"
    }

    columns {
      name    = "ingested_at"
      type    = "string"
      comment = "ISO 8601 datetime when the record was written to S3 by Hamm Lambda"
    }
  }

  partition_keys {
    name    = "dt"
    type    = "date"
    comment = "Partition date (YYYY-MM-DD) — managed by Partition Projection"
  }
}
