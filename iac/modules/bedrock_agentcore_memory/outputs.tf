output "memory_id" {
  description = "ID of the Bedrock AgentCore Memory resource"
  value       = aws_bedrockagentcore_memory.main.id
}

output "memory_arn" {
  description = "ARN of the Bedrock AgentCore Memory resource"
  value       = aws_bedrockagentcore_memory.main.arn
}
