# ─── Athena Workgroup ─────────────────────────────────────────────────────────

resource "aws_athena_workgroup" "toy_data" {
  name        = "${var.project_name}-workgroup"
  description = "Workgroup for toy-data-project queries — JSON Lines via Glue + Partition Projection"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${var.athena_results_bucket}/query-results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }

    bytes_scanned_cutoff_per_query = 1073741824
  }
}

# ─── Named Queries ────────────────────────────────────────────────────────────

resource "aws_athena_named_query" "latest_readings" {
  name        = "latest-sensor-readings"
  workgroup   = aws_athena_workgroup.toy_data.id
  database    = var.glue_database_name
  description = "100 most recent sensor readings"

  query = <<-SQL
    SELECT *
    FROM ${var.glue_database_name}.sensor_readings
    ORDER BY timestamp DESC
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
      date_trunc('hour', from_unixtime(timestamp / 1000)) AS hour,
      ROUND(AVG(temperature), 2) AS avg_temperature,
      ROUND(AVG(humidity), 2)    AS avg_humidity,
      COUNT(*)                   AS reading_count
    FROM ${var.glue_database_name}.sensor_readings
    WHERE dt >= current_date - interval '1' day
    GROUP BY sensor_id, date_trunc('hour', from_unixtime(timestamp / 1000))
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
