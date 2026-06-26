variable "project_name" {
  type = string
}

variable "aws_account_id" {
  description = "AWS account ID — used to ensure globally unique bucket names"
  type        = string
}
