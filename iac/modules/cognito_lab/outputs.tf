output "pool_id" {
  description = "ID of the MCPServerPool Cognito User Pool"
  value       = aws_cognito_user_pool.mcp_server_pool.id
}

output "client_id" {
  description = "App client ID for the MCPServerPoolClient"
  value       = aws_cognito_user_pool_client.mcp_server_pool_client.id
}

output "client_secret" {
  description = "App client secret for the MCPServerPoolClient"
  value       = aws_cognito_user_pool_client.mcp_server_pool_client.client_secret
  sensitive   = true
}

output "discovery_url" {
  description = "OAuth2 discovery URL for the MCPServerPool"
  value       = "https://cognito-idp.${data.aws_region.current.region}.amazonaws.com/${aws_cognito_user_pool.mcp_server_pool.id}/.well-known/openid-configuration"
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret holding the MCPServerPool cognito_config"
  value       = aws_secretsmanager_secret.cognito_config.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret holding the MCPServerPool cognito_config"
  value       = aws_secretsmanager_secret.cognito_config.name
}
