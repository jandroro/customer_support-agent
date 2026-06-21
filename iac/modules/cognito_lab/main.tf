# ──────────────────────────────────────────────────────────────────────────────
# Cognito lab pool — isolated from modules/cognito (the production User Pool).
#
# Purpose: provide a quick USER_PASSWORD_AUTH-based pool for local MCP server
# testing from notebooks. Test-user creation and bearer-token retrieval remain
# in Python (no Terraform resource exists for Cognito users, and access tokens
# expire in minutes — neither belongs in declarative state).
# ──────────────────────────────────────────────────────────────────────────────

data "aws_region" "current" {}

# ------------------------------------------------------------------------------
# Cognito User Pool — MCPServerPool
# ------------------------------------------------------------------------------
resource "aws_cognito_user_pool" "mcp_server_pool" {
  name = "MCPServerPool"

  password_policy {
    minimum_length = 8
  }

  tags = var.tags
}

# ------------------------------------------------------------------------------
# App Client — supports USER_PASSWORD_AUTH for fast local/notebook testing
# ------------------------------------------------------------------------------
resource "aws_cognito_user_pool_client" "mcp_server_pool_client" {
  name         = "MCPServerPoolClient"
  user_pool_id = aws_cognito_user_pool.mcp_server_pool.id

  generate_secret = true

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]
}

# ------------------------------------------------------------------------------
# SSM Parameters — namespaced under mcp_lab/ to avoid colliding with the
# production Cognito parameters written by modules/cognito.
# ------------------------------------------------------------------------------
resource "aws_ssm_parameter" "pool_id" {
  name        = "/app/customersupport/agentcore/mcp_lab/pool_id"
  type        = "String"
  value       = aws_cognito_user_pool.mcp_server_pool.id
  description = "MCPServerPool Cognito User Pool ID (lab)"
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

resource "aws_ssm_parameter" "client_id" {
  name        = "/app/customersupport/agentcore/mcp_lab/client_id"
  type        = "String"
  value       = aws_cognito_user_pool_client.mcp_server_pool_client.id
  description = "MCPServerPoolClient Cognito App Client ID (lab)"
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

resource "aws_ssm_parameter" "client_secret" {
  name        = "/app/customersupport/agentcore/mcp_lab/client_secret"
  type        = "SecureString"
  value       = aws_cognito_user_pool_client.mcp_server_pool_client.client_secret
  description = "MCPServerPoolClient Cognito App Client secret (lab)"
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

resource "aws_ssm_parameter" "discovery_url" {
  name        = "/app/customersupport/agentcore/mcp_lab/cognito_discovery_url"
  type        = "String"
  value       = "https://cognito-idp.${data.aws_region.current.region}.amazonaws.com/${aws_cognito_user_pool.mcp_server_pool.id}/.well-known/openid-configuration"
  description = "MCPServerPool OAuth2 Discovery URL (lab)"
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

# ------------------------------------------------------------------------------
# Secrets Manager — exclusive cognito_config container for MCPServerPool.
# Terraform owns the secret container so its lifecycle is tied to the pool it
# describes; the bearer token and other runtime fields are written by
# lab_helpers.utils.save_customer_support_secret() (Python) via update_secret,
# since short-lived tokens don't belong in declarative state.
# ------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "cognito_config" {
  name                    = "customer_support_agent"
  description             = "Cognito configuration (pool_id, client_id, client_secret, bearer_token, discovery_url) for the MCPServerPool lab gateway client."
  recovery_window_in_days = 0

  tags = var.tags
}
