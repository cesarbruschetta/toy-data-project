terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # Backend remoto — descomente e ajuste antes do primeiro apply em produção
  # backend "s3" {
  #   bucket         = "toy-data-project-tfstate"
  #   key            = "terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "toy-data-project-tflock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}

# ─── Data sources ─────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}

# ─── Módulos ──────────────────────────────────────────────────────────────────

# S3 Tables + Iceberg (substitui o módulo storage antigo)
module "s3_tables" {
  source = "./modules/s3_tables"

  project_name   = var.project_name
  aws_account_id = data.aws_caller_identity.current.account_id
}

module "messaging" {
  source = "./modules/messaging"

  project_name   = var.project_name
  aws_account_id = data.aws_caller_identity.current.account_id
}

module "iam" {
  source = "./modules/iam"

  project_name          = var.project_name
  s3_tables_bucket_arn  = module.s3_tables.table_bucket_arn
  athena_bucket         = module.s3_tables.athena_results_bucket_arn
  sns_topic_arn         = module.messaging.sns_topic_arn
  sqs_queue_arn         = module.messaging.sqs_queue_arn
  glue_database_name    = var.glue_database_name
}

module "lambda" {
  source = "./modules/lambda"

  project_name             = var.project_name
  andy_role_arn            = module.iam.andy_lambda_role_arn
  hamm_role_arn            = module.iam.hamm_lambda_role_arn
  sns_topic_arn            = module.messaging.sns_topic_arn
  sqs_queue_arn            = module.messaging.sqs_queue_arn
  sqs_queue_url            = module.messaging.sqs_queue_url
  lambdas_source_dir       = "${path.module}/../lambdas"
  hamm_schedule_expression = var.hamm_schedule_expression

  # Iceberg / S3 Tables
  s3_tables_arn       = module.s3_tables.table_bucket_arn
  s3_tables_namespace = module.s3_tables.namespace
  s3_tables_table     = module.s3_tables.table_name
}

module "api_gateway" {
  source = "./modules/api_gateway"

  project_name           = var.project_name
  aws_account_id         = data.aws_caller_identity.current.account_id
  andy_lambda_arn        = module.lambda.andy_lambda_arn
  andy_lambda_invoke_arn = module.lambda.andy_lambda_invoke_arn
  custom_domain          = var.custom_domain
}

module "glue" {
  source = "./modules/glue"

  project_name          = var.project_name
  glue_database_name    = var.glue_database_name
  s3_tables_catalog_arn = module.s3_tables.table_bucket_arn
  s3_tables_namespace   = module.s3_tables.namespace
  s3_tables_table_arn   = module.s3_tables.table_arn
}

module "athena" {
  source = "./modules/athena"

  project_name          = var.project_name
  athena_results_bucket = module.s3_tables.athena_results_bucket_name
  glue_database_name    = var.glue_database_name
}
