terraform {
  required_version = "~> 1.14.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.48.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.8.0"
    }
  }

  backend "s3" {
    bucket  = "dev-643626749185-project-tfstate"
    key     = "terraform/toy-data-project.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
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

# ─── Módulos ──────────────────────────────────────────────────────────────────

module "storage" {
  source = "./modules/storage"

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

  project_name              = var.project_name
  data_lake_bucket_arn      = module.storage.data_lake_bucket_arn
  athena_results_bucket_arn = module.storage.athena_results_bucket_arn
  sns_topic_arn             = module.messaging.sns_topic_arn
  sqs_queue_arn             = module.messaging.sqs_queue_arn
  glue_database_name        = var.glue_database_name
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
  data_lake_bucket_name    = module.storage.data_lake_bucket_name
  data_lake_bucket_arn     = module.storage.data_lake_bucket_arn
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
  data_lake_bucket_name = module.storage.data_lake_bucket_name
}

module "athena" {
  source = "./modules/athena"

  project_name          = var.project_name
  athena_results_bucket = module.storage.athena_results_bucket_name
  glue_database_name    = var.glue_database_name
}

# ─── Data sources ─────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}
