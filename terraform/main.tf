locals {
  normalized_name = lower(replace(var.application_name, "_", "-"))
  lambda_zip      = "${path.module}/../build/function.zip"
}

data "archive_file" "lambda_package" {
  type        = "zip"
  source_file = "${path.module}/../build/bootstrap"
  output_path = local.lambda_zip
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_execution" {
  name               = "${local.normalized_name}-lambda-execution"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_kms_decrypt" {
  count = var.lambda_kms_key_arn == "" ? 0 : 1

  statement {
    effect = "Allow"

    actions = [
      "kms:Decrypt",
    ]

    resources = [
      var.lambda_kms_key_arn,
    ]
  }
}

resource "aws_iam_role_policy" "lambda_kms_decrypt" {
  count = var.lambda_kms_key_arn == "" ? 0 : 1

  name   = "${local.normalized_name}-kms-decrypt"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.lambda_kms_decrypt[0].json
}

# checkov:skip=CKV_AWS_158:CloudWatch Logs uses AWS-managed encryption for this assignment.
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.normalized_name}"
  retention_in_days = var.log_retention_days
}

# checkov:skip=CKV_AWS_158:CloudWatch Logs uses AWS-managed encryption for this assignment.
resource "aws_cloudwatch_log_group" "api_access" {
  name              = "/aws/apigateway/${local.normalized_name}"
  retention_in_days = var.log_retention_days
}

# checkov:skip=CKV_AWS_115:Reserved concurrency is omitted to keep this assignment deploy simple.
# checkov:skip=CKV_AWS_116:A dead-letter queue is not required for the simple synchronous HTTP backend.
# checkov:skip=CKV_AWS_117:This public HTTP API Lambda does not need VPC-only networking for the assignment.
# checkov:skip=CKV_AWS_173:Lambda environment variables use AWS-managed encryption for this assignment.
# checkov:skip=CKV_AWS_272:Code signing is intentionally omitted for this lightweight assignment deployment.
resource "aws_lambda_function" "backend" {
  function_name    = local.normalized_name
  description      = "Serverless backend for ${var.application_name}"
  role             = aws_iam_role.lambda_execution.arn
  runtime          = "provided.al2023"
  handler          = "bootstrap"
  architectures    = ["arm64"]
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256
  timeout          = var.lambda_timeout_seconds
  memory_size      = var.lambda_memory_mb
  kms_key_arn      = var.lambda_kms_key_arn == "" ? null : var.lambda_kms_key_arn

  environment {
    variables = {
      APP_NAME              = var.application_name
      HUGGINGFACE_API_TOKEN = var.huggingface_api_token
      HUGGINGFACE_MODEL_URL = var.huggingface_model_url
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_basic_execution,
  ]
}

# checkov:skip=CKV_AWS_316:The public assignment API allows browser callers from any origin.
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.application_name}-http-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers = ["Content-Type"]
    allow_methods = ["OPTIONS", "POST"]
    allow_origins = ["*"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.backend.invoke_arn
  payload_format_version = "2.0"
}

# checkov:skip=CKV_AWS_309:The assignment requires a simple public API endpoint.
resource "aws_apigatewayv2_route" "invoke" {
  api_id             = aws_apigatewayv2_api.http_api.id
  authorization_type = "NONE"
  route_key          = "POST /invoke"
  target             = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn
    format = jsonencode({
      requestId                 = "$context.requestId"
      ip                        = "$context.identity.sourceIp"
      requestTime               = "$context.requestTime"
      httpMethod                = "$context.httpMethod"
      routeKey                  = "$context.routeKey"
      status                    = "$context.status"
      protocol                  = "$context.protocol"
      responseLength            = "$context.responseLength"
      integrationErrorMessage   = "$context.integrationErrorMessage"
      integrationStatus         = "$context.integrationStatus"
      integrationRequestId      = "$context.integration.requestId"
      integrationLatency        = "$context.integrationLatency"
      authorizerError           = "$context.authorizer.error"
      authorizerIntegrationCode = "$context.authorizer.integrationStatus"
    })
  }
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromHttpApi"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*/*"
}
