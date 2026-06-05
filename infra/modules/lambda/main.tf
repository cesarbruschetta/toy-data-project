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

  runtime = "python3.12"
  handler = "handler.lambda_handler"
  role    = var.hamm_role_arn

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
