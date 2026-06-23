# ─── Empacotamento dos zips ───────────────────────────────────────────────────

data "archive_file" "andy" {
  type        = "zip"
  source_dir  = "${var.lambdas_source_dir}/andy"
  output_path = "${path.module}/dist/andy.zip"
}

data "archive_file" "hamm" {
  type        = "zip"
  source_dir  = "${var.lambdas_source_dir}/hamm"
  output_path = "${path.module}/dist/hamm.zip"

  # Exclui artefatos de build que não devem ir no deployment package
  excludes = [
    "dist",
    "__pycache__",
    "*.pyc",
    ".pytest_cache",
    "tests",
    ".venv",
    "build_layer.sh",
  ]
}

# ─── S3 bucket para artefatos de deploy ──────────────────────────────────────
# Usado para upload do Lambda Layer (>70 MB — acima do limite de upload direto)

resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project_name}-lambda-artifacts"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload do layer zip para o S3
resource "aws_s3_object" "hamm_layer" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "layers/hamm_layer.zip"
  source = "${path.module}/dist/hamm_layer.zip"
  etag   = filemd5("${path.module}/dist/hamm_layer.zip")
}

# ─── Lambda Layer — dependências nativas da Hamm ─────────────────────────────
# Build via: make lambda-build-layer-hamm (requer Docker)

resource "aws_lambda_layer_version" "hamm_deps" {
  layer_name  = "${var.project_name}-hamm-deps"
  description = "Dependências do Hamm Lambda (linux/x86_64)"

  # Upload via S3 — evita o limite de 70 MB do upload direto
  s3_bucket         = aws_s3_bucket.artifacts.id
  s3_key            = aws_s3_object.hamm_layer.key
  source_code_hash  = filebase64sha256("${path.module}/dist/hamm_layer.zip")

  compatible_runtimes      = ["python3.12"]
  compatible_architectures = ["x86_64"]
}

# ─── Lambda Andy (producer) ───────────────────────────────────────────────────

resource "aws_lambda_function" "andy" {
  function_name = "${var.project_name}-andy"
  description   = "Receives sensor data via HTTP and publishes to SNS"

  filename         = data.archive_file.andy.output_path
  source_code_hash = data.archive_file.andy.output_base64sha256

  runtime = "python3.12"
  handler = "handler.lambda_handler"
  role    = var.andy_role_arn
  timeout = 30

  environment {
    variables = {
      SNS_TOPIC_ARN = var.sns_topic_arn
    }
  }

  tracing_config {
    mode = "Active"
  }
}

resource "aws_cloudwatch_log_group" "andy" {
  name              = "/aws/lambda/${aws_lambda_function.andy.function_name}"
  retention_in_days = 14
}

# ─── Lambda Hamm (consumer) ───────────────────────────────────────────────────

resource "aws_lambda_function" "hamm" {
  function_name = "${var.project_name}-hamm"
  description   = "Drains SQS queue on schedule and writes to Iceberg table (S3 Tables)"

  filename         = data.archive_file.hamm.output_path
  source_code_hash = data.archive_file.hamm.output_base64sha256

  runtime       = "python3.12"
  handler       = "handler.lambda_handler"
  role          = var.hamm_role_arn
  architectures = ["x86_64"]

  # Layer com PyArrow + PyIceberg compilados para Linux x86_64
  layers = [aws_lambda_layer_version.hamm_deps.arn]

  # Timeout generoso — drena a fila inteira a cada execução
  timeout = 300

  # Não reservar concorrência — usa o pool da conta
  # Se precisar limitar a 1 execução simultânea, use -1 (unreserved) + SQS visibility timeout
  reserved_concurrent_executions = -1

  # Mais memória para PyArrow/PyIceberg
  memory_size = 512

  environment {
    variables = {
      S3_TABLES_ARN       = var.s3_tables_arn
      S3_TABLES_NAMESPACE = var.s3_tables_namespace
      S3_TABLES_TABLE     = var.s3_tables_table
      SQS_QUEUE_URL       = var.sqs_queue_url
      SQS_BATCH_SIZE      = "10"
    }
  }

  tracing_config {
    mode = "Active"
  }
}

resource "aws_cloudwatch_log_group" "hamm" {
  name              = "/aws/lambda/${aws_lambda_function.hamm.function_name}"
  retention_in_days = 14
}

# ─── EventBridge — agenda a Hamm para drenar a fila ──────────────────────────

resource "aws_cloudwatch_event_rule" "hamm_schedule" {
  name                = "${var.project_name}-hamm-schedule"
  description         = "Triggers Hamm Lambda to drain SQS queue on a schedule"
  schedule_expression = var.hamm_schedule_expression
}

resource "aws_cloudwatch_event_target" "hamm_schedule_target" {
  rule      = aws_cloudwatch_event_rule.hamm_schedule.name
  target_id = "HammLambda"
  arn       = aws_lambda_function.hamm.arn
}

resource "aws_lambda_permission" "eventbridge_invoke_hamm" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hamm.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.hamm_schedule.arn
}
