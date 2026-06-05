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

variable "hamm_schedule_expression" {
  description = "EventBridge schedule for the Hamm drain job (e.g. 'rate(1 hour)', 'rate(6 hours)', 'cron(0 */6 * * ? *)')"
  type        = string
  default     = "rate(6 hours)"
}

variable "custom_domain" {
  description = <<-EOT
    Custom domain for the Andy API.
    Leave empty to use only the default API Gateway URL.
    When set, an ACM certificate is created and two DNS records must be
    configured manually in the OVH panel after the first terraform apply.
  EOT
  type        = string
  default     = "andy-api.aws.our-cluster.ovh"
}
