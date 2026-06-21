data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role" "csa_runtime_role" {
  name = "${var.name_prefix}-runtime-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "bedrock-agentcore.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "csa_runtime_policy" {
  name = "${var.name_prefix}-runtime-policy"
  role = aws_iam_role.csa_runtime_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRTokenAccess"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid      = "ECRImageAccess"
        Effect   = "Allow"
        Action   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
        Resource = var.ecr_repository_arn
      },
      {
        Sid    = "BedrockModelInvocation"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:ApplyGuardrail",
          "bedrock:Retrieve",
        ]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/*",
          "arn:aws:bedrock:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:DescribeLogStreams", "logs:CreateLogGroup"]
        Resource = ["arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock-agentcore/runtimes/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = ["arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:*"]
      },
      {
        Effect = "Allow"
        Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock-agentcore/runtimes/*:log-stream:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
        ]
        Resource = ["*"]
      },
      {
        Effect   = "Allow"
        Resource = "*"
        Action   = "cloudwatch:PutMetricData"
        Condition = {
          StringEquals = { "cloudwatch:namespace" = "bedrock-agentcore" }
        }
      },
      {
        Sid    = "GetAgentAccessToken"
        Effect = "Allow"
        Action = [
          "bedrock-agentcore:GetWorkloadAccessToken",
          "bedrock-agentcore:GetWorkloadAccessTokenForJWT",
          "bedrock-agentcore:GetWorkloadAccessTokenForUserId",
        ]
        Resource = [
          "arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:workload-identity-directory/default",
          "arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:workload-identity-directory/default/workload-identity/${replace(var.name_prefix, "-", "_")}_runtime-*",
        ]
      },
      {
        Sid    = "AllowAgentToUseMemory"
        Effect = "Allow"
        Action = [
          "bedrock-agentcore:CreateEvent",
          "bedrock-agentcore:ListEvents",
          "bedrock-agentcore:GetMemoryRecord",
          "bedrock-agentcore:GetMemory",
          "bedrock-agentcore:RetrieveMemoryRecords",
          "bedrock-agentcore:ListMemoryRecords",
        ]
        Resource = ["arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"]
      },
      {
        Sid      = "GetMemoryId"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = ["arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/app/customersupport/*"]
      },
      {
        # get_technical_support() (agent_helpers/strands_agent.py) reads the
        # Knowledge Base ID from a different SSM path prefix than the rest of
        # the app (modules/bedrock_kb uses /{account}-{region}/kb/... instead
        # of /app/customersupport/...) — needs its own statement.
        Sid      = "GetKnowledgeBaseId"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = ["arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}/kb/*"]
      },
      {
        Sid    = "GatewayAccess"
        Effect = "Allow"
        Action = [
          "bedrock-agentcore:GetGateway",
          "bedrock-agentcore:InvokeGateway",
        ]
        Resource = ["arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:gateway/*"]
      },
    ]
  })
}

resource "aws_bedrockagentcore_agent_runtime" "csa_runtime" {
  # agent_runtime_name must match ^[a-zA-Z][a-zA-Z0-9_]{0,47}$ — no hyphens allowed,
  # unlike most other AWS resource names, so name_prefix's hyphens are replaced here only.
  agent_runtime_name = "${replace(var.name_prefix, "-", "_")}"
  description        = "Customer Support Agent developed on Bedrock AgentCore"
  role_arn           = aws_iam_role.csa_runtime_role.arn

  agent_runtime_artifact {
    container_configuration {
      container_uri = var.container_image_uri
    }
  }

  environment_variables = var.environment_variables

  network_configuration {
    network_mode = "PUBLIC"
  }

  authorizer_configuration {
    custom_jwt_authorizer {
      allowed_clients = [var.allowed_client_id]
      discovery_url   = var.discovery_url
    }
  }

  request_header_configuration {
    request_header_allowlist = [
      "Authorization",
      "X-Amzn-Bedrock-AgentCore-Runtime-Custom-H1",
    ]
  }

  tags = var.tags
}

resource "aws_ssm_parameter" "runtime_arn" {
  name        = "/app/customersupport/agentcore/runtime_arn"
  type        = "String"
  value       = aws_bedrockagentcore_agent_runtime.csa_runtime.agent_runtime_arn
  description = "ARN of the Bedrock AgentCore Runtime"
  overwrite   = true
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

# ------------------------------------------------------------------------------
# Observability (CloudWatch Logs) — vended log delivery pipeline.
#
# Unlike Memory/Gateway, Runtime resources get a basic auto-created log group
# for raw container logs with no setup required. The structured APPLICATION_LOGS
# (request/response payloads, trace_id/span_id) and USAGE_LOGS (per-session
# CPU/memory consumption) log types still require explicit vended-log delivery,
# same CloudWatch Logs Delivery API used in modules/bedrock_agentcore_memory and
# modules/bedrock_agentcore_gateway.
#
# TRACES delivery also applies to Runtime — it's the "Tracing" toggle shown
# separately from "Log delivery" under Runtime > Log deliveries and tracing in
# the console. Same CW Logs Delivery -> XRAY destination mechanism as Memory/Gateway.
# ------------------------------------------------------------------------------

# aws_cloudwatch_log_delivery_source/_destination names are capped at 60 chars.
# agent_runtime_id is already 44+ chars, so descriptive suffixes overflow the
# limit — truncate the id and use short suffixes to stay safely under it
# regardless of how long AWS's generated id/random suffix ends up being.
locals {
  runtime_log_name_prefix = substr(aws_bedrockagentcore_agent_runtime.csa_runtime.agent_runtime_id, 0, 40)
}

# Application logs — vended log group + delivery source/destination/delivery
resource "aws_cloudwatch_log_group" "runtime_application_logs" {
  name              = "/aws/vendedlogs/bedrock-agentcore/runtime/APPLICATION_LOGS/${aws_bedrockagentcore_agent_runtime.csa_runtime.agent_runtime_id}"
  retention_in_days = 30

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery_source" "runtime_application_logs" {
  name         = "${local.runtime_log_name_prefix}-app-src"
  log_type     = "APPLICATION_LOGS"
  resource_arn = aws_bedrockagentcore_agent_runtime.csa_runtime.agent_runtime_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery_destination" "runtime_application_logs" {
  name                      = "${local.runtime_log_name_prefix}-app-dst"
  delivery_destination_type = "CWL"

  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.runtime_application_logs.arn
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery" "runtime_application_logs" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.runtime_application_logs.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.runtime_application_logs.arn

  tags = var.tags
}

# Usage logs — session-level CPU/memory consumption, same delivery pattern
resource "aws_cloudwatch_log_group" "runtime_usage_logs" {
  name              = "/aws/vendedlogs/bedrock-agentcore/runtime/USAGE_LOGS/${aws_bedrockagentcore_agent_runtime.csa_runtime.agent_runtime_id}"
  retention_in_days = 30

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery_source" "runtime_usage_logs" {
  name         = "${local.runtime_log_name_prefix}-usg-src"
  log_type     = "USAGE_LOGS"
  resource_arn = aws_bedrockagentcore_agent_runtime.csa_runtime.agent_runtime_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery_destination" "runtime_usage_logs" {
  name                      = "${local.runtime_log_name_prefix}-usg-dst"
  delivery_destination_type = "CWL"

  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.runtime_usage_logs.arn
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery" "runtime_usage_logs" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.runtime_usage_logs.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.runtime_usage_logs.arn

  tags = var.tags
}

# Traces — delivery source/destination/delivery to X-Ray. Corresponds to the
# "Tracing" toggle under Runtime > Log deliveries and tracing in the console
# (separate from the Log delivery section above), same delivery mechanism
# already used in modules/bedrock_agentcore_memory and modules/bedrock_agentcore_gateway.
resource "aws_cloudwatch_log_delivery_source" "runtime_traces" {
  name         = "${local.runtime_log_name_prefix}-trc-src"
  log_type     = "TRACES"
  resource_arn = aws_bedrockagentcore_agent_runtime.csa_runtime.agent_runtime_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery_destination" "runtime_traces" {
  name                      = "${local.runtime_log_name_prefix}-trc-dst"
  delivery_destination_type = "XRAY"

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery" "runtime_traces" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.runtime_traces.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.runtime_traces.arn

  tags = var.tags
}
