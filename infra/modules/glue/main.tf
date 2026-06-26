# ─── Glue Database ───────────────────────────────────────────────────────────

resource "aws_glue_catalog_database" "toy_data" {
  name        = var.glue_database_name
  description = "Landing zone — raw IoT sensor data in JSON Lines (S3 data lake)"
}

# ─── Glue Table com Partition Projection ─────────────────────────────────────
# Sem crawler — partições inferidas automaticamente por Partition Projection.
# Path: s3://<bucket>/raw/toydata-topic-temperature-v1/dt=YYYY-MM-DD/

resource "aws_glue_catalog_table" "sensor_readings" {
  name          = "sensor_readings"
  database_name = aws_glue_catalog_database.toy_data.name
  description   = "Raw sensor readings — JSON Lines partitioned by dt"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"                        = "json"
    "projection.enabled"                    = "true"
    "projection.dt.type"                    = "date"
    "projection.dt.format"                  = "yyyy-MM-dd"
    "projection.dt.range"                   = "2024-01-01,NOW"
    "projection.dt.interval"                = "1"
    "projection.dt.interval.unit"           = "DAYS"
    "storage.location.template"             = "s3://${var.data_lake_bucket_name}/raw/toydata-topic-temperature-v1/dt=$${dt}"
  }

  storage_descriptor {
    location      = "s3://${var.data_lake_bucket_name}/raw/toydata-topic-temperature-v1/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name    = "sensor_id"
      type    = "string"
    }
    columns {
      name = "temperature"
      type = "double"
    }
    columns {
      name = "humidity"
      type = "double"
    }
    columns {
      name = "heat_index"
      type = "double"
    }
    columns {
      name = "pressure"
      type = "double"
    }
    columns {
      name = "altitude"
      type = "double"
    }
    columns {
      name = "temperature_bmp"
      type = "double"
    }
    columns {
      name = "timestamp"
      type = "bigint"
    }
    columns {
      name = "ingested_at"
      type = "string"
    }
  }

  partition_keys {
    name = "dt"
    type = "date"
  }
}
