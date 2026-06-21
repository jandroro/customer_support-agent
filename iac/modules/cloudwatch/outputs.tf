output "log_group_name" {
  description = "Name of the CloudWatch Log Group for Bedrock Model Invocation Logging"
  value       = aws_cloudwatch_log_group.bedrock_model_invocation_logging.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch Log Group for Bedrock Model Invocation Logging"
  value       = aws_cloudwatch_log_group.bedrock_model_invocation_logging.arn
}

output "logging_role_arn" {
  description = "ARN of the IAM role bedrock.amazonaws.com assumes to write model invocation logs"
  value       = aws_iam_role.bedrock_model_invocation_logging.arn
}
