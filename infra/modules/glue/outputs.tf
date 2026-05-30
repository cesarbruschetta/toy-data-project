output "glue_database_name" {
  value = aws_glue_catalog_database.toy_data.name
}

output "glue_table_name" {
  value = aws_glue_catalog_table.sensor_readings.name
}

output "glue_connection_name" {
  description = "Name of the Glue connection to S3 Tables"
  value       = aws_glue_connection.s3_tables.name
}
