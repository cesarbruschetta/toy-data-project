variable "project_name" {
  type = string
}

variable "glue_database_name" {
  type = string
}

variable "s3_tables_catalog_arn" {
  description = "ARN of the S3 Tables Table Bucket (Iceberg catalog)"
  type        = string
}

variable "s3_tables_namespace" {
  description = "Namespace in S3 Tables (e.g. 'raw')"
  type        = string
}

variable "s3_tables_table_arn" {
  description = "ARN of the sensor_readings table in S3 Tables"
  type        = string
}
