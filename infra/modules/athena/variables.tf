variable "project_name" {
  type = string
}

variable "athena_results_bucket" {
  description = "Name of the S3 bucket for Athena query results"
  type        = string
}

variable "glue_database_name" {
  description = "Name of the Glue database to query"
  type        = string
}
