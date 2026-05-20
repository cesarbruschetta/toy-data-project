output "andy_lambda_role_arn" {
  value = aws_iam_role.andy_lambda.arn
}

output "hamm_lambda_role_arn" {
  value = aws_iam_role.hamm_lambda.arn
}

output "athena_role_arn" {
  value = aws_iam_role.athena.arn
}
