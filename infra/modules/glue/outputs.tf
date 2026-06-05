output "glue_database_name" {
  value = aws_glue_catalog_database.toy_data.name
}

output "glue_table_name" {
  value = aws_glue_catalog_table.sensor_readings.name
}

output "s3_tables_query_hint" {
  description = "Query pattern for Athena to access S3 Tables Iceberg data"
  value       = "SELECT * FROM \"s3tablescatalog\".\"${var.s3_tables_namespace}\".\"sensor_readings\""
}
