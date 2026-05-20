variable "project_name" {
  type = string
}

variable "glue_database_name" {
  type = string
}

variable "data_lake_bucket" {
  description = "Name of the S3 data lake bucket"
  type        = string
}

variable "raw_prefix" {
  description = "S3 prefix for raw zone"
  type        = string
}

variable "topic_name" {
  description = "Topic/stream name used as S3 path segment"
  type        = string
}
