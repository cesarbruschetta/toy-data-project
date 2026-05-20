output "api_gateway_url" {
  description = "Base URL of the API Gateway"
  value       = module.api_gateway.api_url
}

output "api_temperature_endpoint" {
  description = "Full URL for POST /temperature"
  value       = "${module.api_gateway.api_url}/temperature"
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic"
  value       = module.messaging.sns_topic_arn
}

output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = module.messaging.sqs_queue_url
}

output "sqs_dlq_url" {
  description = "URL of the SQS Dead Letter Queue"
  value       = module.messaging.sqs_dlq_url
}

output "data_lake_bucket" {
  description = "Name of the S3 data lake bucket"
  value       = module.storage.data_lake_bucket_name
}

output "athena_results_bucket" {
  description = "Name of the S3 bucket for Athena query results"
  value       = module.storage.athena_results_bucket_name
}

output "glue_database_name" {
  description = "Name of the Glue catalog database"
  value       = module.glue.glue_database_name
}

output "glue_table_name" {
  description = "Name of the Glue catalog table"
  value       = module.glue.glue_table_name
}

output "athena_workgroup" {
  description = "Name of the Athena workgroup"
  value       = module.athena.workgroup_name
}

output "andy_lambda_name" {
  description = "Name of the Andy producer Lambda"
  value       = module.lambda.andy_lambda_name
}

output "hamm_lambda_name" {
  description = "Name of the Hamm consumer Lambda"
  value       = module.lambda.hamm_lambda_name
}

output "hamm_schedule" {
  description = "EventBridge schedule for the Hamm drain job"
  value       = var.hamm_schedule_expression
}
