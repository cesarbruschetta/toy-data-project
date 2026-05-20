variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name — used as prefix for all AWS resource names"
  type        = string
  default     = "toy-data-project"
}

variable "glue_database_name" {
  description = "Name of the Glue catalog database"
  type        = string
  default     = "toy_data_raw"
}

variable "topic_name" {
  description = "Topic/stream name — used as the S3 path segment for raw data"
  type        = string
  default     = "toydata-topic-temperature-v1"
}

variable "raw_prefix" {
  description = "S3 prefix for the raw zone"
  type        = string
  default     = "raw"
}

variable "hamm_schedule_expression" {
  description = "EventBridge schedule for the Hamm drain job (e.g. 'rate(1 hour)', 'rate(6 hours)', 'cron(0 */6 * * ? *)')"
  type        = string
  default     = "rate(6 hour)"
}
