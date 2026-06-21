output "gateway_id" {
  description = "ID of the Bedrock AgentCore Gateway"
  value       = aws_bedrockagentcore_gateway.main.gateway_id
}

output "gateway_arn" {
  description = "ARN of the Bedrock AgentCore Gateway"
  value       = aws_bedrockagentcore_gateway.main.gateway_arn
}

output "gateway_url" {
  description = "URL of the Bedrock AgentCore Gateway"
  value       = aws_bedrockagentcore_gateway.main.gateway_url
}

output "log_group_name" {
  description = "Name of the CloudWatch Log Group receiving vended gateway APPLICATION_LOGS"
  value       = aws_cloudwatch_log_group.gateway_logs.name
}

output "lambda_target_id" {
  description = "ID of the LambdaUsingSDK gateway target"
  value       = aws_bedrockagentcore_gateway_target.lambda.target_id
}

output "policy_engine_id" {
  description = "ID of the Bedrock AgentCore Policy Engine"
  value       = aws_bedrockagentcore_policy_engine.main.policy_engine_id
}

output "policy_engine_arn" {
  description = "ARN of the Bedrock AgentCore Policy Engine"
  value       = aws_bedrockagentcore_policy_engine.main.policy_engine_arn
}

output "allow_tools_policy_id" {
  description = "ID of the allow_policy Cedar policy"
  value       = aws_bedrockagentcore_policy.allow_tools.policy_id
}

output "deny_web_search_iphone8_policy_id" {
  description = "ID of the deny_web_search Cedar policy"
  value       = aws_bedrockagentcore_policy.deny_web_search_iphone8.policy_id
}
