output "user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "web_client_id" {
  description = "App client ID for the web (SPA) client"
  value       = aws_cognito_user_pool_client.web.id
}

output "machine_client_id" {
  description = "App client ID for the machine (M2M) client"
  value       = aws_cognito_user_pool_client.machine.id
  sensitive   = true
}

output "cognito_domain" {
  description = "Full Cognito hosted-UI base URL"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.region}.amazoncognito.com"
}
