output "api_url" {
  description = "Base URL of the deployed API Gateway stage"
  value       = aws_api_gateway_stage.andy.invoke_url
}

output "rest_api_id" {
  value = aws_api_gateway_rest_api.andy.id
}

output "stage_name" {
  value = aws_api_gateway_stage.andy.stage_name
}
