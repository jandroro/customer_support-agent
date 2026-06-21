output "online_evaluation_config_id" {
  description = "ID of the Online Evaluation Config"
  value       = aws_bedrockagentcore_online_evaluation_config.main.online_evaluation_config_id
}

output "online_evaluation_config_arn" {
  description = "ARN of the Online Evaluation Config"
  value       = aws_bedrockagentcore_online_evaluation_config.main.online_evaluation_config_arn
}

output "evaluation_role_arn" {
  description = "ARN of the IAM role used by the evaluator"
  value       = aws_iam_role.evaluation.arn
}

output "output_log_group_name" {
  description = "Name of the CloudWatch Log Group auto-created by AgentCore for evaluation results"
  value       = try(aws_bedrockagentcore_online_evaluation_config.main.output_config[0].cloudwatch_config[0].log_group_name, null)
}
