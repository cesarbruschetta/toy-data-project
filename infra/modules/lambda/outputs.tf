output "andy_lambda_arn" {
  value = aws_lambda_function.andy.arn
}

output "andy_lambda_invoke_arn" {
  value = aws_lambda_function.andy.invoke_arn
}

output "andy_lambda_name" {
  value = aws_lambda_function.andy.function_name
}

output "hamm_lambda_arn" {
  value = aws_lambda_function.hamm.arn
}

output "hamm_lambda_name" {
  value = aws_lambda_function.hamm.function_name
}
