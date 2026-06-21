output "lambda_arn" {
  description = "ARN of the CustomerSupport Lambda function"
  value       = aws_lambda_function.customer_support.arn
}

output "lambda_function_name" {
  description = "Name of the CustomerSupport Lambda function"
  value       = aws_lambda_function.customer_support.function_name
}

output "ddgs_layer_arn" {
  description = "ARN of the DDGS Lambda Layer version"
  value       = aws_lambda_layer_version.ddgs.arn
}

output "gateway_agentcore_role_arn" {
  description = "ARN of the GatewayAgentCoreRole"
  value       = aws_iam_role.gateway_agentcore.arn
}

output "lambda_role_arn" {
  description = "ARN of the CustomerSupportLambda execution role"
  value       = aws_iam_role.customer_support_lambda.arn
}
