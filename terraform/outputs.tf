output "api_endpoint" {
  description = "Stable HTTP API endpoint for NSP-4-S2-S25App."
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

output "invoke_url" {
  description = "POST endpoint for Lambda invocation."
  value       = "${aws_apigatewayv2_api.http_api.api_endpoint}/invoke"
}

output "lambda_function_name" {
  description = "Deployed Lambda function name."
  value       = aws_lambda_function.backend.function_name
}
