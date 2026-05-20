variable "project_name" {
  type = string
}

variable "data_lake_bucket" {
  description = "ARN of the data lake S3 bucket"
  type        = string
}

variable "athena_bucket" {
  description = "ARN of the Athena results S3 bucket"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic"
  type        = string
}

variable "sqs_queue_arn" {
  description = "ARN of the SQS queue"
  type        = string
}

variable "glue_database_name" {
  description = "Name of the Glue database"
  type        = string
}
