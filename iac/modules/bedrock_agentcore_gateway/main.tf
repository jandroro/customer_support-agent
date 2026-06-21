# ──────────────────────────────────────────────────────────────────────────────
# Bedrock AgentCore Gateway — MCP protocol endpoint, authorized via the
# MCPServerPool Cognito client (modules/cognito_lab). Mirrors the gateway
# created via the Python SDK (gateway_client.create_gateway) in lab_helpers.
# ──────────────────────────────────────────────────────────────────────────────

locals {
  gateway_name = "customersupport-gw"
}

resource "aws_bedrockagentcore_gateway" "main" {
  name          = local.gateway_name
  description   = "Customer Support AgentCore Gateway"
  role_arn      = var.gateway_role_arn
  protocol_type = "MCP"

  authorizer_type = "CUSTOM_JWT"

  authorizer_configuration {
    custom_jwt_authorizer {
      allowed_clients = [var.allowed_client_id]
      discovery_url   = var.discovery_url
    }
  }

  # Policy engine + Cedar policies are defined further below in this same
  # module (not a separate module) to avoid a circular dependency: the
  # policies' Cedar statements need this gateway's ARN, while this block
  # needs the policy engine's ARN.
  policy_engine_configuration {
    arn  = aws_bedrockagentcore_policy_engine.main.policy_engine_arn
    mode = "ENFORCE"
  }

  tags = var.tags
}

# ------------------------------------------------------------------------------
# SSM Parameters — gateway identifiers consumed at runtime
# (matches lab_helpers.utils put_ssm_parameter calls for the gateway)
# ------------------------------------------------------------------------------
resource "aws_ssm_parameter" "gateway_id" {
  name        = "/app/customersupport/agentcore/gateway_id"
  type        = "String"
  value       = aws_bedrockagentcore_gateway.main.gateway_id
  description = "Bedrock AgentCore Gateway ID"
  overwrite   = true
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

resource "aws_ssm_parameter" "gateway_name" {
  name        = "/app/customersupport/agentcore/gateway_name"
  type        = "String"
  value       = local.gateway_name
  description = "Bedrock AgentCore Gateway name"
  overwrite   = true
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

resource "aws_ssm_parameter" "gateway_arn" {
  name        = "/app/customersupport/agentcore/gateway_arn"
  type        = "String"
  value       = aws_bedrockagentcore_gateway.main.gateway_arn
  description = "Bedrock AgentCore Gateway ARN"
  overwrite   = true
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

resource "aws_ssm_parameter" "gateway_url" {
  name        = "/app/customersupport/agentcore/gateway_url"
  type        = "String"
  value       = aws_bedrockagentcore_gateway.main.gateway_url
  description = "Bedrock AgentCore Gateway URL"
  overwrite   = true
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

# ------------------------------------------------------------------------------
# Observability (CloudWatch Logs + X-Ray) — vended log/trace delivery pipeline.
# Mirrors modules/bedrock_agentcore_memory and the boto3 enable_observability_for_resource()
# pattern documented for AgentCore gateway resources: APPLICATION_LOGS -> CWL,
# TRACES -> XRAY, using the default log group naming convention.
# ------------------------------------------------------------------------------

# Logs — vended log group + delivery source/destination/delivery
resource "aws_cloudwatch_log_group" "gateway_logs" {
  name              = "/aws/vendedlogs/bedrock-agentcore/gateway/APPLICATION_LOGS/${aws_bedrockagentcore_gateway.main.gateway_id}"
  retention_in_days = 30

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery_source" "gateway_logs" {
  name         = "${aws_bedrockagentcore_gateway.main.gateway_id}-logs-source"
  log_type     = "APPLICATION_LOGS"
  resource_arn = aws_bedrockagentcore_gateway.main.gateway_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery_destination" "gateway_logs" {
  name                      = "${aws_bedrockagentcore_gateway.main.gateway_id}-logs-destination"
  delivery_destination_type = "CWL"

  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.gateway_logs.arn
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery" "gateway_logs" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.gateway_logs.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.gateway_logs.arn

  tags = var.tags
}

# Traces — delivery source/destination/delivery to X-Ray
resource "aws_cloudwatch_log_delivery_source" "gateway_traces" {
  name         = "${aws_bedrockagentcore_gateway.main.gateway_id}-traces-source"
  log_type     = "TRACES"
  resource_arn = aws_bedrockagentcore_gateway.main.gateway_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery_destination" "gateway_traces" {
  name                      = "${aws_bedrockagentcore_gateway.main.gateway_id}-traces-destination"
  delivery_destination_type = "XRAY"

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery" "gateway_traces" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.gateway_traces.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.gateway_traces.arn

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Gateway Target — exposes the CustomerSupport Lambda as an MCP tool target.
# Tool definitions mirror prerequisite/lambda/api_spec.json; the Lambda target
# schema requires structured HCL blocks (no raw JSON inline_payload for Lambda
# targets, unlike OpenAPI/Smithy targets).
# ------------------------------------------------------------------------------
resource "aws_bedrockagentcore_gateway_target" "lambda" {
  gateway_identifier = aws_bedrockagentcore_gateway.main.gateway_id
  name               = "LambdaUsingSDK"
  description        = "Lambda Target using SDK"

  credential_provider_configuration {
    gateway_iam_role {}
  }

  target_configuration {
    mcp {
      lambda {
        lambda_arn = var.lambda_arn

        tool_schema {
          inline_payload {
            name        = "check_warranty_status"
            description = "Check the warranty status of a product using its serial number and optionally verify via email"

            input_schema {
              type = "object"

              property {
                name     = "serial_number"
                type     = "string"
                required = true
              }

              property {
                name     = "customer_email"
                type     = "string"
                required = false
              }
            }
          }

          inline_payload {
            name        = "web_search"
            description = "Search the web for updated information using DuckDuckGo"

            input_schema {
              type = "object"

              property {
                name        = "keywords"
                type        = "string"
                description = "The search query keywords"
                required    = true
              }

              property {
                name        = "region"
                type        = "string"
                description = "The search region (e.g., us-en, uk-en, ru-ru)"
                required    = false
              }

              property {
                name        = "max_results"
                type        = "integer"
                description = "The maximum number of results to return"
                required    = false
              }
            }
          }
        }
      }
    }
  }
}

resource "aws_ssm_parameter" "gateway_target_id" {
  name        = "/app/customersupport/agentcore/gateway_target_id"
  type        = "String"
  value       = aws_bedrockagentcore_gateway_target.lambda.target_id
  description = "Bedrock AgentCore Gateway Target ID (LambdaUsingSDK)"
  overwrite   = true
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

# ------------------------------------------------------------------------------
# Policy Engine — container for the Cedar authorization policies that gate
# access to this gateway's tools. Mirrors PolicyClient.create_or_get_policy_engine()
# in lab_helpers (notebooks/lab-03-agentcore-gateway.ipynb).
#
# Lives in this module (not a separate one) because it's attached to the
# gateway above via policy_engine_configuration, and its policies reference
# the gateway's ARN — keeping both in one module avoids a cross-module cycle.
#
# NL-generated policies (PolicyClient.generate_policy) remain in Python — that
# step is an LLM authoring aid, not a deterministic resource. Once a Cedar
# statement is finalized, it graduates here as a static aws_bedrockagentcore_policy.
# ------------------------------------------------------------------------------
resource "aws_bedrockagentcore_policy_engine" "main" {
  name        = "customersupport_pe"
  description = "Policy engine for customer support gateway"

  tags = var.tags
}

resource "aws_ssm_parameter" "policy_engine_id" {
  name        = "/app/customersupport/agentcore/policy_engine_id"
  type        = "String"
  value       = aws_bedrockagentcore_policy_engine.main.policy_engine_id
  description = "Bedrock AgentCore Policy Engine ID"
  overwrite   = true
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

resource "aws_ssm_parameter" "policy_engine_arn" {
  name        = "/app/customersupport/agentcore/policy_engine_arn"
  type        = "String"
  value       = aws_bedrockagentcore_policy_engine.main.policy_engine_arn
  description = "Bedrock AgentCore Policy Engine ARN"
  overwrite   = true
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

# ------------------------------------------------------------------------------
# Cedar Policies — finalized, static authorization rules for the LambdaUsingSDK
# gateway target. Mirrors the hardcoded allow_policy/deny_web_search_policy
# definitions in lab_helpers (notebooks/lab-03-agentcore-gateway.ipynb).
# validation_mode is fixed to IGNORE_ALL_FINDINGS to match the script's retry
# fallback, since Terraform can't perform the create/inspect-error/retry dance.
#
# depends_on is required here: the statements reference actions derived from
# the gateway target (LambdaUsingSDK___<tool>), but only via a string built
# from a hardcoded target/tool name, not a resource attribute reference.
# Terraform can't infer this dependency on its own, so without depends_on the
# policy can be created before the target registers its action schema,
# causing Cedar validation to fail with "unrecognized action".
# ------------------------------------------------------------------------------
resource "aws_bedrockagentcore_policy" "allow_tools" {
  policy_engine_id = aws_bedrockagentcore_policy_engine.main.policy_engine_id
  name             = "allow_policy"
  description      = "Allow web_search and check_warranty_status calls"
  validation_mode  = "IGNORE_ALL_FINDINGS"

  depends_on = [aws_bedrockagentcore_gateway_target.lambda]

  definition {
    cedar {
      statement = <<-CEDAR
        permit(
            principal,
            action in [AgentCore::Action::"LambdaUsingSDK___check_warranty_status", AgentCore::Action::"LambdaUsingSDK___web_search"],
            resource == AgentCore::Gateway::"${aws_bedrockagentcore_gateway.main.gateway_arn}"
        ) when {
            (principal.hasTag("username")) &&
            ((principal.getTag("username")) == "testuser")
        };
      CEDAR
    }
  }
}

resource "aws_ssm_parameter" "allow_policy_id" {
  name        = "/app/customersupport/agentcore/allow_policy_id"
  type        = "String"
  value       = aws_bedrockagentcore_policy.allow_tools.policy_id
  description = "ID of the allow_policy Cedar policy"
  overwrite   = true
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

resource "aws_bedrockagentcore_policy" "deny_web_search_iphone8" {
  policy_engine_id = aws_bedrockagentcore_policy_engine.main.policy_engine_id
  name             = "deny_web_search"
  description      = "Deny web_search tool call for iPhone 8"
  validation_mode  = "IGNORE_ALL_FINDINGS"

  depends_on = [aws_bedrockagentcore_gateway_target.lambda]

  definition {
    cedar {
      statement = <<-CEDAR
        forbid(
            principal,
            action == AgentCore::Action::"LambdaUsingSDK___web_search",
            resource == AgentCore::Gateway::"${aws_bedrockagentcore_gateway.main.gateway_arn}"
        ) when {
            context.input has keywords &&
            context.input.keywords like "*iPhone 8*"
        };
      CEDAR
    }
  }
}

resource "aws_ssm_parameter" "deny_web_search_policy_id" {
  name        = "/app/customersupport/agentcore/deny_web_search_policy_id"
  type        = "String"
  value       = aws_bedrockagentcore_policy.deny_web_search_iphone8.policy_id
  description = "ID of the deny_web_search Cedar policy"
  overwrite   = true
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}
