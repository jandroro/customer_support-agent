data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ------------------------------------------------------------------------------
# IAM role — assumed by the AgentCore evaluator/online-evaluation-config
# execution context to read source traces and write evaluation results.
# ------------------------------------------------------------------------------
resource "aws_iam_role" "evaluation" {
  name = "${var.name_prefix}-evaluation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "TrustPolicyStatement"
      Effect    = "Allow"
      Principal = { Service = "bedrock-agentcore.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:ResourceAccount" = data.aws_caller_identity.current.account_id
          "aws:SourceAccount"   = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = [
            "arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:evaluator/*",
            "arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:online-evaluation-config/*",
          ]
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "evaluation" {
  name = "${var.name_prefix}-evaluation-policy"
  role = aws_iam_role.evaluation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogReadStatement"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetQueryResults",
          "logs:StartQuery",
          "cloudwatch:GenerateQuery",
          "cloudwatch:GenerateQueryResultsSummary",
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogWriteStatement"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock-agentcore/evaluations/*"
      },
      {
        Sid    = "CloudWatchIndexPolicyStatement"
        Effect = "Allow"
        Action = [
          "logs:DescribeIndexPolicies",
          "logs:PutIndexPolicy",
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:aws/spans",
          "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:aws/spans:*",
        ]
      },
      {
        Sid    = "BedrockInvokeStatement"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
        ]
        Resource = "*"
      },
    ]
  })
}

# ------------------------------------------------------------------------------
# Online Evaluation Config — sources logs from the DEFAULT endpoint's own
# vended log group (the endpoint that actually receives traffic today).
# ------------------------------------------------------------------------------
resource "aws_bedrockagentcore_online_evaluation_config" "main" {
  online_evaluation_config_name = "customer_support_agent_eval"
  description                   = "Customer support agent online evaluation"
  enable_on_create              = true
  evaluation_execution_role_arn = aws_iam_role.evaluation.arn

  data_source_config {
    cloudwatch_logs {
      log_group_names = ["/aws/bedrock-agentcore/runtimes/${var.runtime_id}-DEFAULT"]
      # NOT the Terraform agent_runtime_name — confirmed by inspecting the
      # actual OTEL resource attributes in the otel-rt-logs stream, where
      # service.name comes from the container's OTEL_SERVICE_NAME env var
      # (docker/Dockerfile), independent of the Terraform resource name.
      service_names = ["${var.otel_service_name}.DEFAULT"]
    }
  }

  evaluator {
    evaluator_id = "Builtin.GoalSuccessRate"
  }
  evaluator {
    evaluator_id = "Builtin.Correctness"
  }
  evaluator {
    evaluator_id = "Builtin.ToolSelectionAccuracy"
  }

  rule {
    sampling_config {
      sampling_percentage = 100
    }
  }

  tags = var.tags
}

resource "aws_ssm_parameter" "online_evaluation_config_id" {
  name        = "/app/customersupport/agentcore/online_evaluation_config_id"
  type        = "String"
  value       = aws_bedrockagentcore_online_evaluation_config.main.online_evaluation_config_id
  description = "Bedrock AgentCore Online Evaluation Config ID"
  overwrite   = true
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}
