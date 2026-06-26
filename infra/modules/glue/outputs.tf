output "glue_database_name" {
  value = aws_glue_catalog_database.toy_data.name
}

output "glue_table_name" {
  value = aws_glue_catalog_table.sensor_readings.name
}
