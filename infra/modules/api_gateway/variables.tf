variable "project_name" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "andy_lambda_arn" {
  description = "ARN of the Andy Lambda function"
  type        = string
}

variable "andy_lambda_invoke_arn" {
  description = "Invoke ARN of the Andy Lambda function"
  type        = string
}

variable "custom_domain" {
  description = <<-EOT
    Custom domain name for the API Gateway (e.g. "andy-api.k8s.our-cluster.ovh").
    Leave empty to use only the default API Gateway URL.
    When set, an ACM certificate and a custom domain mapping are created.
    After apply, two DNS records must be created manually in the OVH panel:
      - CNAME for ACM certificate validation  (output: acm_validation_cname)
      - CNAME pointing the domain to API GW   (output: custom_domain_target)
  EOT
  type        = string
  default     = ""
}
