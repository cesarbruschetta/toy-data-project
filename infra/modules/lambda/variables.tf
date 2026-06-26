variable "project_name" {
  type = string
}

variable "andy_role_arn" {
  description = "IAM role ARN for the Andy Lambda"
  type        = string
}

variable "hamm_role_arn" {
  description = "IAM role ARN for the Hamm Lambda"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic to publish to"
  type        = string
}

variable "sqs_queue_arn" {
  description = "ARN of the SQS queue"
  type        = string
}

variable "sqs_queue_url" {
  description = "URL of the SQS queue — used by Hamm to poll messages via SDK"
  type        = string
}

variable "lambdas_source_dir" {
  description = "Path to the lambdas source directory"
  type        = string
}

variable "hamm_schedule_expression" {
  description = "EventBridge schedule expression for the Hamm drain job"
  type        = string
  default     = "rate(1 hour)"
}

# ─── S3 Data Lake ─────────────────────────────────────────────────────────────

variable "data_lake_bucket_name" {
  description = "Name of the S3 data lake bucket (landing zone)"
  type        = string
}

variable "data_lake_bucket_arn" {
  description = "ARN of the S3 data lake bucket (for IAM policies)"
  type        = string
}
