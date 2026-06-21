output "policy_arn" {
  description = "ARN of the customer-support agent IAM managed policy"
  value       = aws_iam_policy.customer_support_agent.arn
}

output "policy_name" {
  description = "Name of the customer-support agent IAM managed policy"
  value       = aws_iam_policy.customer_support_agent.name
}

output "policy_id" {
  description = "Unique ID of the customer-support agent IAM managed policy"
  value       = aws_iam_policy.customer_support_agent.id
}

output "lab_role_arn" {
  description = "ARN of the lab-customer-support-agent-role IAM role"
  value       = aws_iam_role.lab_customer_support_agent.arn
}

output "lab_role_name" {
  description = "Name of the lab-customer-support-agent-role IAM role"
  value       = aws_iam_role.lab_customer_support_agent.name
}

output "runtime_agentcore_role_arn" {
  description = "ARN of the RuntimeAgentCoreRole (assumed by bedrock-agentcore)"
  value       = aws_iam_role.runtime_agentcore.arn
}

output "runtime_agentcore_role_name" {
  description = "Name of the RuntimeAgentCoreRole"
  value       = aws_iam_role.runtime_agentcore.name
}
