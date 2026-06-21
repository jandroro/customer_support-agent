# ── IAM ───────────────────────────────────────────────────────────────────────
output "iam_policy_arn" {
  description = "ARN of the customer-support agent IAM managed policy"
  value       = module.iam.policy_arn
}

output "iam_policy_name" {
  description = "Name of the customer-support agent IAM managed policy"
  value       = module.iam.policy_name
}

output "lab_role_arn" {
  description = "ARN of the lab-customer-support-agent-role IAM role"
  value       = module.iam.lab_role_arn
}

output "lab_role_name" {
  description = "Name of the lab-customer-support-agent-role IAM role"
  value       = module.iam.lab_role_name
}

output "runtime_agentcore_role_arn" {
  description = "ARN of the RuntimeAgentCoreRole assumed by bedrock-agentcore"
  value       = module.iam.runtime_agentcore_role_arn
}

# ── S3 ────────────────────────────────────────────────────────────────────────
output "artifacts_bucket_id" {
  description = "Name of the S3 artifacts bucket"
  value       = module.s3.artifacts_bucket_id
}

output "kb_data_bucket_id" {
  description = "Name of the Knowledge Base data S3 bucket"
  value       = module.s3.kb_data_bucket_id
}

# ── DynamoDB ──────────────────────────────────────────────────────────────────
output "warranty_table_name" {
  description = "Name of the warranty DynamoDB table"
  value       = module.dynamodb.warranty_table_name
}

output "customer_profile_table_name" {
  description = "Name of the customer-profile DynamoDB table"
  value       = module.dynamodb.customer_profile_table_name
}

# ── Lambda ────────────────────────────────────────────────────────────────────
output "lambda_arn" {
  description = "ARN of the CustomerSupport Lambda function"
  value       = module.lambda.lambda_arn
}

output "gateway_agentcore_role_arn" {
  description = "ARN of the GatewayAgentCoreRole"
  value       = module.lambda.gateway_agentcore_role_arn
}

# ── Cognito ───────────────────────────────────────────────────────────────────
output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = module.cognito.user_pool_id
}

output "cognito_web_client_id" {
  description = "Cognito app client ID for the web (SPA) client"
  value       = module.cognito.web_client_id
}

output "cognito_domain" {
  description = "Full Cognito hosted-UI base URL"
  value       = module.cognito.cognito_domain
}

# ── Cognito Lab (MCPServerPool) ──────────────────────────────────────────────
output "mcp_lab_pool_id" {
  description = "ID of the MCPServerPool Cognito User Pool (lab)"
  value       = module.cognito_lab.pool_id
}

output "mcp_lab_client_id" {
  description = "App client ID for the MCPServerPoolClient (lab)"
  value       = module.cognito_lab.client_id
}

# ── Bedrock AgentCore Gateway ────────────────────────────────────────────────
output "gateway_id" {
  description = "ID of the Bedrock AgentCore Gateway"
  value       = module.bedrock_agentcore_gateway.gateway_id
}

output "gateway_url" {
  description = "URL of the Bedrock AgentCore Gateway"
  value       = module.bedrock_agentcore_gateway.gateway_url
}

# ── Bedrock AgentCore Policy Engine (part of modules/bedrock_agentcore_gateway) ─
output "policy_engine_id" {
  description = "ID of the Bedrock AgentCore Policy Engine"
  value       = module.bedrock_agentcore_gateway.policy_engine_id
}

# ── Knowledge Base ────────────────────────────────────────────────────────────
output "knowledge_base_id" {
  description = "ID of the Bedrock Knowledge Base"
  value       = module.bedrock_kb.knowledge_base_id
}

output "knowledge_base_arn" {
  description = "ARN of the Bedrock Knowledge Base"
  value       = module.bedrock_kb.knowledge_base_arn
}

output "vector_bucket_name" {
  description = "Name of the S3 Vector Bucket used as embedding store"
  value       = module.bedrock_kb.vector_bucket_name
}

# ── AgentCore Memory ──────────────────────────────────────────────────────────
output "agentcore_memory_id" {
  description = "ID of the Bedrock AgentCore Memory resource"
  value       = module.bedrock_agentcore_memory.memory_id
}

output "agentcore_memory_arn" {
  description = "ARN of the Bedrock AgentCore Memory resource"
  value       = module.bedrock_agentcore_memory.memory_arn
}

# ── ECR ───────────────────────────────────────────────────────────────────────
output "ecr_repository_url" {
  description = "URL of the ECR repository (build/push target for the agent image)"
  value       = module.ecr.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = module.ecr.repository_name
}

# ── Bedrock AgentCore Runtime ────────────────────────────────────────────────
output "agentcore_runtime_id" {
  description = "ID of the Bedrock AgentCore Runtime"
  value       = module.bedrock_agentcore_runtime.runtime_id
}

output "agentcore_runtime_arn" {
  description = "ARN of the Bedrock AgentCore Runtime"
  value       = module.bedrock_agentcore_runtime.runtime_arn
}

# ── Bedrock AgentCore Online Evaluation ──────────────────────────────────────
output "online_evaluation_config_id" {
  description = "ID of the Online Evaluation Config"
  value       = module.bedrock_agentcore_evaluation.online_evaluation_config_id
}

output "evaluation_output_log_group_name" {
  description = "CloudWatch Log Group where evaluation results are written (auto-created by AgentCore)"
  value       = module.bedrock_agentcore_evaluation.output_log_group_name
}

# ── Bedrock Model Invocation Logging ────────────────────────────────────────
output "bedrock_model_invocation_log_group_name" {
  description = "CloudWatch Log Group name to use as the destination for Bedrock Model Invocation Logging (configure manually in the Bedrock console)"
  value       = module.cloudwatch.log_group_name
}

output "bedrock_model_invocation_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for Bedrock Model Invocation Logging"
  value       = module.cloudwatch.log_group_arn
}

output "bedrock_model_invocation_role_arn" {
  description = "ARN of the IAM role to pass as cloudWatchConfig.roleArn when manually configuring Bedrock Model Invocation Logging"
  value       = module.cloudwatch.logging_role_arn
}
