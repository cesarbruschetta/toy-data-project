# ─── SNS Topic ───────────────────────────────────────────────────────────────

resource "aws_sns_topic" "temperature" {
  name = "${var.project_name}-temperature"

}

resource "aws_sns_topic_policy" "temperature" {
  arn = aws_sns_topic.temperature.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaPublish"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.temperature.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = var.aws_account_id
          }
        }
      }
    ]
  })
}

# ─── SQS Dead Letter Queue ───────────────────────────────────────────────────

resource "aws_sqs_queue" "temperature_dlq" {
  name = "${var.project_name}-temperature-dlq"

  # Mensagens ficam na DLQ por 14 dias para análise
  message_retention_seconds = 1209600

}

# ─── SQS Queue principal ─────────────────────────────────────────────────────

resource "aws_sqs_queue" "temperature" {
  name = "${var.project_name}-temperature-queue"

  # Visibility timeout maior que o timeout da Lambda Hamm (300s)
  visibility_timeout_seconds = 360

  # Mensagens ficam na fila por 4 dias se não processadas
  message_retention_seconds = 345600

  delay_seconds = 0

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.temperature_dlq.arn
    # Após 3 tentativas falhas, vai para DLQ
    maxReceiveCount = 3
  })
}

resource "aws_sqs_queue_policy" "temperature" {
  queue_url = aws_sqs_queue.temperature.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSToSendMessage"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.temperature.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.temperature.arn
          }
        }
      }
    ]
  })
}

# ─── SNS → SQS Subscription ──────────────────────────────────────────────────

resource "aws_sns_topic_subscription" "temperature_to_sqs" {
  topic_arn = aws_sns_topic.temperature.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.temperature.arn

  # Entrega a mensagem raw (sem envelope SNS) para a SQS
  raw_message_delivery = true
}
