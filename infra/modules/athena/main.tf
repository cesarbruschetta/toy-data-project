# ─── Athena Workgroup ─────────────────────────────────────────────────────────

resource "aws_athena_workgroup" "toy_data" {
  name        = "${var.project_name}-workgroup"
  description = "Workgroup for toy-data-project queries — Iceberg tables via S3 Tables"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${var.athena_results_bucket}/query-results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }

    # Limite de 1 GB por query — evita scans acidentais caros
    bytes_scanned_cutoff_per_query = 1073741824
  }
}

# ─── Named Queries (Iceberg) ──────────────────────────────────────────────────

resource "aws_athena_named_query" "latest_readings" {
  name        = "latest-sensor-readings"
  workgroup   = aws_athena_workgroup.toy_data.id
  database    = var.glue_database_name
  description = "100 most recent sensor readings"

  query = <<-SQL
    SELECT
      sensor_id,
      temperature,
      humidity,
      heat_index,
      pressure,
      altitude,
      from_unixtime(event_timestamp / 1000) AS event_time,
      dt
    FROM ${var.glue_database_name}.sensor_readings
    ORDER BY event_timestamp DESC
    LIMIT 100;
  SQL
}

resource "aws_athena_named_query" "daily_avg" {
  name        = "daily-average-by-sensor"
  workgroup   = aws_athena_workgroup.toy_data.id
  database    = var.glue_database_name
  description = "Daily average temperature and humidity per sensor"

  query = <<-SQL
    SELECT
      dt,
      sensor_id,
      ROUND(AVG(temperature), 2)  AS avg_temperature,
      ROUND(AVG(humidity), 2)     AS avg_humidity,
      ROUND(AVG(heat_index), 2)   AS avg_heat_index,
      ROUND(MIN(temperature), 2)  AS min_temperature,
      ROUND(MAX(temperature), 2)  AS max_temperature,
      COUNT(*)                    AS reading_count
    FROM ${var.glue_database_name}.sensor_readings
    GROUP BY dt, sensor_id
    ORDER BY dt DESC, sensor_id;
  SQL
}

resource "aws_athena_named_query" "hourly_avg" {
  name        = "hourly-average-last-24h"
  workgroup   = aws_athena_workgroup.toy_data.id
  database    = var.glue_database_name
  description = "Hourly average for the last 24 hours"

  query = <<-SQL
    SELECT
      sensor_id,
      date_trunc('hour', from_unixtime(event_timestamp / 1000)) AS hour,
      ROUND(AVG(temperature), 2) AS avg_temperature,
      ROUND(AVG(humidity), 2)    AS avg_humidity,
      COUNT(*)                   AS reading_count
    FROM ${var.glue_database_name}.sensor_readings
    WHERE dt >= current_date - interval '1' day
    GROUP BY sensor_id, date_trunc('hour', from_unixtime(event_timestamp / 1000))
    ORDER BY hour DESC, sensor_id;
  SQL
}

resource "aws_athena_named_query" "sensor_list" {
  name        = "active-sensors"
  workgroup   = aws_athena_workgroup.toy_data.id
  database    = var.glue_database_name
  description = "All sensors with their last reading date"

  query = <<-SQL
    SELECT
      sensor_id,
      MAX(dt)                    AS last_seen_date,
      COUNT(*)                   AS total_readings,
      ROUND(AVG(temperature), 2) AS overall_avg_temp
    FROM ${var.glue_database_name}.sensor_readings
    GROUP BY sensor_id
    ORDER BY last_seen_date DESC;
  SQL
}

# ─── Iceberg-specific Named Queries ───────────────────────────────────────────

resource "aws_athena_named_query" "time_travel_snapshot" {
  name        = "time-travel-snapshot-history"
  workgroup   = aws_athena_workgroup.toy_data.id
  database    = var.glue_database_name
  description = "List all Iceberg snapshots (for time travel queries)"

  query = <<-SQL
    -- Lista todos os snapshots disponíveis para time travel
    SELECT *
    FROM ${var.glue_database_name}."sensor_readings$snapshots"
    ORDER BY committed_at DESC
    LIMIT 20;
  SQL
}

resource "aws_athena_named_query" "time_travel_query" {
  name        = "time-travel-point-in-time"
  workgroup   = aws_athena_workgroup.toy_data.id
  database    = var.glue_database_name
  description = "Query data as of a specific timestamp (time travel)"

  query = <<-SQL
    -- Query dados como estavam em um ponto específico no tempo
    -- Substitua o timestamp conforme necessário
    SELECT
      sensor_id,
      temperature,
      humidity,
      event_timestamp,
      dt
    FROM ${var.glue_database_name}.sensor_readings
    FOR TIMESTAMP AS OF TIMESTAMP '2025-01-15 12:00:00'
    ORDER BY event_timestamp DESC
    LIMIT 50;
  SQL
}

resource "aws_athena_named_query" "table_metadata" {
  name        = "iceberg-table-metadata"
  workgroup   = aws_athena_workgroup.toy_data.id
  database    = var.glue_database_name
  description = "Iceberg table metadata: files, partitions, and statistics"

  query = <<-SQL
    -- Metadados da tabela Iceberg: arquivos Parquet
    SELECT
      file_path,
      file_format,
      record_count,
      file_size_in_bytes,
      partition
    FROM ${var.glue_database_name}."sensor_readings$files"
    ORDER BY record_count DESC
    LIMIT 50;
  SQL
}

resource "aws_athena_named_query" "partition_stats" {
  name        = "partition-statistics"
  workgroup   = aws_athena_workgroup.toy_data.id
  database    = var.glue_database_name
  description = "Statistics per partition (dt)"

  query = <<-SQL
    -- Estatísticas por partição
    SELECT
      dt,
      COUNT(*) AS record_count,
      ROUND(AVG(temperature), 2) AS avg_temp,
      ROUND(MIN(temperature), 2) AS min_temp,
      ROUND(MAX(temperature), 2) AS max_temp
    FROM ${var.glue_database_name}.sensor_readings
    GROUP BY dt
    ORDER BY dt DESC;
  SQL
}
