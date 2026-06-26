variable "project_name" {
  type = string
}

variable "glue_database_name" {
  type = string
}

variable "data_lake_bucket_name" {
  description = "Name of the S3 data lake bucket"
  type        = string
}
