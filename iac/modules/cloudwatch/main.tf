# ──────────────────────────────────────────────────────────────────────────────
# CloudWatch — destination log group for Bedrock Model Invocation Logging.
# Not wired to a resource here; configure it manually as the destination under
# Bedrock console > Settings > Model invocation logging.
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "bedrock_model_invocation_logging" {
  name              = "/aws/bedrock/${var.name_prefix}/model-invocation-logging"
  retention_in_days = 30

  tags = var.tags
}

# ------------------------------------------------------------------------------
# IAM role — assumed by bedrock.amazonaws.com to deliver model invocation logs
# to the log group above. Pass this role's ARN as cloudWatchConfig.roleArn when
# manually configuring Model invocation logging in the Bedrock console.
# ------------------------------------------------------------------------------
resource "aws_iam_role" "bedrock_model_invocation_logging" {
  name = "${var.name_prefix}-bedrock-logging-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "bedrock_model_invocation_logging" {
  name = "bedrock-model-invocation-logging-policy"
  role = aws_iam_role.bedrock_model_invocation_logging.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
        ]
        Resource = [
          aws_cloudwatch_log_group.bedrock_model_invocation_logging.arn,
          "${aws_cloudwatch_log_group.bedrock_model_invocation_logging.arn}:log-stream:*",
        ]
      }
    ]
  })
}
