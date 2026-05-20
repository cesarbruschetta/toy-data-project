# ─── REST API ─────────────────────────────────────────────────────────────────

resource "aws_api_gateway_rest_api" "andy" {
  name        = "${var.project_name}-andy-api"
  description = "Andy API — receives IoT sensor data and forwards to SNS via Lambda"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# ─── /temperature resource ────────────────────────────────────────────────────

resource "aws_api_gateway_resource" "temperature" {
  rest_api_id = aws_api_gateway_rest_api.andy.id
  parent_id   = aws_api_gateway_rest_api.andy.root_resource_id
  path_part   = "temperature"
}

resource "aws_api_gateway_method" "temperature_post" {
  rest_api_id   = aws_api_gateway_rest_api.andy.id
  resource_id   = aws_api_gateway_resource.temperature.id
  http_method   = "POST"
  authorization = "NONE"

  request_validator_id = aws_api_gateway_request_validator.body.id

  request_models = {
    "application/json" = aws_api_gateway_model.temperature_payload.name
  }
}

resource "aws_api_gateway_integration" "temperature_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.andy.id
  resource_id             = aws_api_gateway_resource.temperature.id
  http_method             = aws_api_gateway_method.temperature_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.andy_lambda_invoke_arn
}

# ─── /health-check resource ───────────────────────────────────────────────────

resource "aws_api_gateway_resource" "health_check" {
  rest_api_id = aws_api_gateway_rest_api.andy.id
  parent_id   = aws_api_gateway_rest_api.andy.root_resource_id
  path_part   = "health-check"
}

resource "aws_api_gateway_method" "health_check_get" {
  rest_api_id   = aws_api_gateway_rest_api.andy.id
  resource_id   = aws_api_gateway_resource.health_check.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "health_check_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.andy.id
  resource_id             = aws_api_gateway_resource.health_check.id
  http_method             = aws_api_gateway_method.health_check_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.andy_lambda_invoke_arn
}

# ─── Request Validator ────────────────────────────────────────────────────────

resource "aws_api_gateway_request_validator" "body" {
  name                        = "validate-body"
  rest_api_id                 = aws_api_gateway_rest_api.andy.id
  validate_request_body       = true
  validate_request_parameters = false
}

# ─── JSON Schema para validação do payload ────────────────────────────────────

resource "aws_api_gateway_model" "temperature_payload" {
  rest_api_id  = aws_api_gateway_rest_api.andy.id
  name         = "TemperaturePayload"
  description  = "Schema for sensor temperature payload"
  content_type = "application/json"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "TemperaturePayload"
    type      = "object"
    required  = ["sensor_id", "temperature", "humidity", "heat_index"]
    properties = {
      sensor_id       = { type = "string" }
      temperature     = { type = "number" }
      humidity        = { type = "number" }
      heat_index      = { type = "number" }
      pressure        = { type = "number" }
      altitude        = { type = "number" }
      temperature_bmp = { type = "number" }
    }
  })
}

# ─── Deployment e Stage ───────────────────────────────────────────────────────

resource "aws_api_gateway_deployment" "andy" {
  rest_api_id = aws_api_gateway_rest_api.andy.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.temperature.id,
      aws_api_gateway_method.temperature_post.id,
      aws_api_gateway_integration.temperature_lambda.id,
      aws_api_gateway_resource.health_check.id,
      aws_api_gateway_method.health_check_get.id,
      aws_api_gateway_integration.health_check_lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "andy" {
  deployment_id = aws_api_gateway_deployment.andy.id
  rest_api_id   = aws_api_gateway_rest_api.andy.id
  stage_name    = "v1"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      errorMessage   = "$context.error.message"
    })
  }

  xray_tracing_enabled = true
}

resource "aws_api_gateway_method_settings" "andy" {
  rest_api_id = aws_api_gateway_rest_api.andy.id
  stage_name  = aws_api_gateway_stage.andy.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

# ─── CloudWatch Logs ──────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/api-gateway/${var.project_name}-andy-api"
  retention_in_days = 14
}

# ─── Lambda permission para API Gateway ──────────────────────────────────────

resource "aws_lambda_permission" "api_gateway_invoke_andy" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.andy_lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.andy.execution_arn}/*/*"
}

# ─── Throttling (proteção básica) ────────────────────────────────────────────

resource "aws_api_gateway_usage_plan" "andy" {
  name        = "${var.project_name}-andy-usage-plan"
  description = "Usage plan for Andy API"

  api_stages {
    api_id = aws_api_gateway_rest_api.andy.id
    stage  = aws_api_gateway_stage.andy.stage_name
  }

  throttle_settings {
    burst_limit = 50
    rate_limit  = 20
  }

  quota_settings {
    limit  = 10000
    period = "DAY"
  }
}
