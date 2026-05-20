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
