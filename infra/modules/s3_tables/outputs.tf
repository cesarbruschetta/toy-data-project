output "table_bucket_arn" {
  description = "ARN of the S3 Table Bucket"
  value       = aws_s3tables_table_bucket.data_lake.arn
}

output "table_bucket_name" {
  description = "Name of the S3 Table Bucket"
  value       = aws_s3tables_table_bucket.data_lake.name
}

output "namespace" {
  description = "Namespace (schema) for raw data"
  value       = aws_s3tables_namespace.raw.namespace
}

output "table_name" {
  description = "Name of the sensor_readings Iceberg table"
  value       = aws_s3tables_table.sensor_readings.name
}

output "table_arn" {
  description = "ARN of the sensor_readings table"
  value       = aws_s3tables_table.sensor_readings.arn
}

output "athena_results_bucket_name" {
  description = "Name of the S3 bucket for Athena query results"
  value       = aws_s3_bucket.athena_results.id
}

output "athena_results_bucket_arn" {
  description = "ARN of the S3 bucket for Athena query results"
  value       = aws_s3_bucket.athena_results.arn
}

# Catalog ARN para uso no Athena — formato especial para S3 Tables
output "iceberg_catalog_arn" {
  description = "ARN to use as Iceberg catalog in Athena queries"
  value       = aws_s3tables_table_bucket.data_lake.arn
}
