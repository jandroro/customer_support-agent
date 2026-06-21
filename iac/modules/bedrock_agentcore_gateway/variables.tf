variable "gateway_role_arn" {
  description = "ARN of the IAM role assumed by the AgentCore Gateway (GatewayAgentCoreRole)"
  type        = string
}

variable "allowed_client_id" {
  description = "Cognito app client ID authorized to obtain JWTs accepted by the gateway (MCPServerPoolClient)"
  type        = string
}

variable "discovery_url" {
  description = "OIDC discovery URL of the Cognito User Pool issuing the JWTs (MCPServerPool)"
  type        = string
}

variable "lambda_arn" {
  description = "ARN of the CustomerSupport Lambda function exposed as an MCP tool target"
  type        = string
}

variable "tags" {
  description = "Tags propagated to all resources"
  type        = map(string)
  default     = {}
}
