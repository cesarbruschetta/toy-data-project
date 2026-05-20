output "sns_topic_arn" {
  value = aws_sns_topic.temperature.arn
}

output "sns_topic_name" {
  value = aws_sns_topic.temperature.name
}

output "sqs_queue_arn" {
  value = aws_sqs_queue.temperature.arn
}

output "sqs_queue_url" {
  value = aws_sqs_queue.temperature.url
}

output "sqs_dlq_arn" {
  value = aws_sqs_queue.temperature_dlq.arn
}

output "sqs_dlq_url" {
  value = aws_sqs_queue.temperature_dlq.url
}
