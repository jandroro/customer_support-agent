output "runtime_role_arn" {
  description = "ARN of the IAM role used by the runtime"
  value       = aws_iam_role.csa_runtime_role.arn
}

output "runtime_id" {
  description = "ID of the AgentCore runtime"
  value       = aws_bedrockagentcore_agent_runtime.csa_runtime.agent_runtime_id
}

output "runtime_arn" {
  description = "ARN of the AgentCore runtime"
  value       = aws_bedrockagentcore_agent_runtime.csa_runtime.agent_runtime_arn
}

output "runtime_version" {
  description = "Version of the AgentCore runtime"
  value       = aws_bedrockagentcore_agent_runtime.csa_runtime.agent_runtime_version
}

output "runtime_name" {
  description = "Name of the AgentCore runtime (agent_runtime_name)"
  value       = aws_bedrockagentcore_agent_runtime.csa_runtime.agent_runtime_name
}

output "application_logs_group_name" {
  description = "Name of the CloudWatch Log Group receiving vended runtime APPLICATION_LOGS"
  value       = aws_cloudwatch_log_group.runtime_application_logs.name
}

output "usage_logs_group_name" {
  description = "Name of the CloudWatch Log Group receiving vended runtime USAGE_LOGS"
  value       = aws_cloudwatch_log_group.runtime_usage_logs.name
}
