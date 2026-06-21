data "aws_region" "current" {}

locals {
  # Resource server identifier — deterministic, derived from name_prefix
  resource_server_id = "${var.name_prefix}-m2m-resource-server"
  # Full OAuth2 scope string used by both clients
  m2m_scope = "${local.resource_server_id}/read"
}

# ------------------------------------------------------------------------------
# Cognito User Pool
# ------------------------------------------------------------------------------
resource "aws_cognito_user_pool" "main" {
  name              = var.user_pool_name
  mfa_configuration = "OPTIONAL"

  username_configuration {
    case_sensitive = false
  }

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  software_token_mfa_configuration {
    enabled = true
  }

  tags = var.tags
}

# Groups — aws_cognito_user_pool_group was removed in aws provider v6; use awscc
resource "awscc_cognito_user_pool_group" "admin" {
  group_name   = "admin"
  description  = "Administrator group"
  user_pool_id = aws_cognito_user_pool.main.id
  precedence   = 1
}

resource "awscc_cognito_user_pool_group" "customer" {
  group_name   = "customer"
  description  = "Regular customer group"
  user_pool_id = aws_cognito_user_pool.main.id
  precedence   = 2
}

# ------------------------------------------------------------------------------
# Resource Server — defines the M2M OAuth2 scope
# aws_cognito_user_pool_resource_server was removed in aws provider v6; use awscc
# ------------------------------------------------------------------------------
resource "awscc_cognito_user_pool_resource_server" "m2m" {
  name         = "${var.name_prefix} M2M Resource Server"
  identifier   = local.resource_server_id
  user_pool_id = aws_cognito_user_pool.main.id

  scopes = [{
    scope_name        = "read"
    scope_description = "Read scope for M2M authentication"
  }]
}

# ------------------------------------------------------------------------------
# Cognito Hosted UI domain
# ------------------------------------------------------------------------------
resource "aws_cognito_user_pool_domain" "main" {
  domain       = var.name_prefix
  user_pool_id = aws_cognito_user_pool.main.id

  depends_on = [aws_cognito_user_pool.main]
}

# ------------------------------------------------------------------------------
# Web App Client — Authorization Code Flow (SPA / Streamlit)
# ------------------------------------------------------------------------------
resource "aws_cognito_user_pool_client" "web" {
  name         = var.web_client_name
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile", local.m2m_scope]

  callback_urls = [
    "http://localhost:8501/",
    "https://example.com/auth/callback",
  ]
  logout_urls = ["http://localhost:8501/"]

  supported_identity_providers = ["COGNITO"]

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  enable_token_revocation = true

  depends_on = [awscc_cognito_user_pool_resource_server.m2m]
}

# ------------------------------------------------------------------------------
# Machine App Client — Client Credentials Flow (agent-to-agent)
# ------------------------------------------------------------------------------
resource "aws_cognito_user_pool_client" "machine" {
  name         = var.machine_client_name
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret                      = true
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["client_credentials"]
  allowed_oauth_scopes                 = [local.m2m_scope]

  explicit_auth_flows = ["ALLOW_REFRESH_TOKEN_AUTH"]

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 1

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  supported_identity_providers = ["COGNITO"]
  enable_token_revocation      = true

  depends_on = [awscc_cognito_user_pool_resource_server.m2m]
}

# ------------------------------------------------------------------------------
# Post-signup Lambda — auto-assigns new users to the "customer" group.
# (Defined in CFN but not wired as a trigger; kept here for parity.)
# ------------------------------------------------------------------------------
resource "aws_iam_role" "post_signup" {
  name = "${var.name_prefix}-post-signup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "post_signup_logs" {
  name = "allow-basic-logs"
  role = aws_iam_role.post_signup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

resource "aws_iam_role_policy" "post_signup_cognito" {
  name = "allow-cognito-add-to-group"
  role = aws_iam_role.post_signup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["cognito-idp:AdminAddUserToGroup"]
      Resource = "*"
    }]
  })
}

data "archive_file" "post_signup" {
  type        = "zip"
  output_path = "${path.module}/post_signup.zip"

  source {
    content  = <<-PYTHON
      import boto3

      def lambda_handler(event, context):
          user_pool_id = event['userPoolId']
          username = event['userName']
          client = boto3.client('cognito-idp')
          try:
              client.admin_add_user_to_group(
                  UserPoolId=user_pool_id,
                  Username=username,
                  GroupName='customer'
              )
              print(f"User {username} added to 'customer' group.")
          except Exception as e:
              print(f"Error adding user to group: {e}")
          return event
    PYTHON
    filename = "index.py"
  }
}

resource "aws_lambda_function" "post_signup" {
  function_name    = "${var.name_prefix}-post-signup"
  role             = aws_iam_role.post_signup.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.13"
  filename         = data.archive_file.post_signup.output_path
  source_code_hash = data.archive_file.post_signup.output_base64sha256
  timeout          = 10

  tags = var.tags
}

# ------------------------------------------------------------------------------
# SSM Parameters — Cognito endpoints and client IDs consumed at runtime
# ------------------------------------------------------------------------------
resource "aws_ssm_parameter" "machine_client_id" {
  name        = "/app/customersupport/agentcore/client_id"
  type        = "String"
  value       = aws_cognito_user_pool_client.machine.id
  description = "Machine Cognito client ID"
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

resource "aws_ssm_parameter" "web_client_id" {
  name        = "/app/customersupport/agentcore/web_client_id"
  type        = "String"
  value       = aws_cognito_user_pool_client.web.id
  description = "Cognito client ID for web app"
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

resource "aws_ssm_parameter" "pool_id" {
  name        = "/app/customersupport/agentcore/pool_id"
  type        = "String"
  value       = aws_cognito_user_pool.main.id
  description = "Cognito User Pool ID"
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

resource "aws_ssm_parameter" "cognito_auth_scope" {
  name        = "/app/customersupport/agentcore/cognito_auth_scope"
  type        = "String"
  value       = local.m2m_scope
  description = "OAuth2 scope for Cognito auth"
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

resource "aws_ssm_parameter" "cognito_discovery_url" {
  name        = "/app/customersupport/agentcore/cognito_discovery_url"
  type        = "String"
  value       = "https://cognito-idp.${data.aws_region.current.region}.amazonaws.com/${aws_cognito_user_pool.main.id}/.well-known/openid-configuration"
  description = "OAuth2 Discovery URL"
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

resource "aws_ssm_parameter" "cognito_token_url" {
  name        = "/app/customersupport/agentcore/cognito_token_url"
  type        = "String"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.region}.amazoncognito.com/oauth2/token"
  description = "OAuth2 Token URL"
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

resource "aws_ssm_parameter" "cognito_auth_url" {
  name        = "/app/customersupport/agentcore/cognito_auth_url"
  type        = "String"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.region}.amazoncognito.com/oauth2/authorize"
  description = "OAuth2 Authorize URL"
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

resource "aws_ssm_parameter" "cognito_domain" {
  name        = "/app/customersupport/agentcore/cognito_domain"
  type        = "String"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.region}.amazoncognito.com"
  description = "Cognito hosted domain for OAuth2"
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}
