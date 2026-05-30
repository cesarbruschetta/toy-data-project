output "api_gateway_url" {
  description = "Base URL of the API Gateway (default AWS domain)"
  value       = module.api_gateway.api_url
}

output "api_temperature_endpoint" {
  description = "Full URL for POST /temperature (default AWS domain)"
  value       = "${module.api_gateway.api_url}/temperature"
}

output "custom_domain_url" {
  description = "Custom domain URL — empty if custom_domain was not configured"
  value       = module.api_gateway.custom_domain_url
}

output "custom_domain_target" {
  description = "CNAME target to configure in OVH DNS for the custom domain"
  value       = module.api_gateway.custom_domain_target
}

output "acm_validation_cname" {
  description = "CNAME record to create in OVH to validate the ACM certificate"
  value       = module.api_gateway.acm_validation_cname
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

# ─── S3 Tables / Iceberg outputs ──────────────────────────────────────────────

output "s3_tables_bucket_arn" {
  description = "ARN of the S3 Tables bucket (Iceberg catalog)"
  value       = module.s3_tables.table_bucket_arn
}

output "s3_tables_bucket_name" {
  description = "Name of the S3 Tables bucket"
  value       = module.s3_tables.table_bucket_name
}

output "iceberg_namespace" {
  description = "Iceberg namespace for raw data"
  value       = module.s3_tables.namespace
}

output "iceberg_table_name" {
  description = "Name of the sensor_readings Iceberg table"
  value       = module.s3_tables.table_name
}

output "iceberg_table_arn" {
  description = "Full ARN of the sensor_readings Iceberg table"
  value       = module.s3_tables.table_arn
}

output "athena_results_bucket" {
  description = "Name of the S3 bucket for Athena query results"
  value       = module.s3_tables.athena_results_bucket_name
}

output "glue_database_name" {
  description = "Name of the Glue database (federated with S3 Tables)"
  value       = module.glue.glue_database_name
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
