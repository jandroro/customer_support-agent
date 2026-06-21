data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ------------------------------------------------------------------------------
# Lambda function zip — built from the Python source directory at plan time
# ------------------------------------------------------------------------------
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = var.lambda_source_path
  output_path = "${path.root}/.build/lambda.zip"
  excludes    = ["ddgs-layer.zip", "__pycache__"]
}

# ------------------------------------------------------------------------------
# DDGS Lambda Layer — pre-built zip shipped alongside the source
# ------------------------------------------------------------------------------
resource "aws_lambda_layer_version" "ddgs" {
  layer_name          = "${var.name_prefix}-ddgs-layer"
  description         = "DuckDuckGo Search (ddgs) package"
  filename            = var.ddgs_layer_zip_path
  source_code_hash    = filebase64sha256(var.ddgs_layer_zip_path)
  compatible_runtimes = ["python3.12"]

  compatible_architectures = ["x86_64"]
}

# ------------------------------------------------------------------------------
# IAM role — CustomerSupportLambda execution role
# ------------------------------------------------------------------------------
resource "aws_iam_role" "customer_support_lambda" {
  name = "${var.name_prefix}-lambda-role"
  path = "/service-role/"

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

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.customer_support_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "customer_support_lambda" {
  name = "customer-support-lambda-policy"
  role = aws_iam_role.customer_support_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowReadCustomerTableNameFromSSM"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/app/customersupport/dynamodb/customer_profile_table_name"
      },
      {
        Sid      = "AllowReadCustomerProfileTable"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:DescribeTable"]
        Resource = var.customer_profile_table_arn
      },
      {
        Sid      = "AllowReadCustomerTableIndexes"
        Effect   = "Allow"
        Action   = ["dynamodb:Query"]
        Resource = "${var.customer_profile_table_arn}/index/*"
      },
      {
        Sid      = "AllowReadWarrantyTableNameFromSSM"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/app/customersupport/dynamodb/warranty_table_name"
      },
      {
        Sid      = "AllowReadWarrantyTable"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:DescribeTable"]
        Resource = var.warranty_table_arn
      },
      {
        Sid      = "CloudWatchLogReadStatement"
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups", "logs:GetQueryResults", "logs:StartQuery"]
        Resource = "*"
      },
      {
        Sid      = "CloudWatchLogWriteStatement"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock-agentcore/evaluations/*"
      },
      {
        Sid    = "CloudWatchIndexPolicyStatement"
        Effect = "Allow"
        Action = ["logs:DescribeIndexPolicies", "logs:PutIndexPolicy"]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:aws/spans",
          "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:aws/spans:*",
        ]
      },
      {
        Sid    = "BedrockInvokeStatement"
        Effect = "Allow"
        Action = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/*",
          "arn:aws:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*",
        ]
      },
    ]
  })
}

# ------------------------------------------------------------------------------
# CustomerSupport Lambda function
# ------------------------------------------------------------------------------
resource "aws_lambda_function" "customer_support" {
  function_name = "${var.name_prefix}-customer-support"
  description   = "Lambda function for Customer Support Assistant"
  role          = aws_iam_role.customer_support_lambda.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  package_type  = "Zip"
  architectures = ["x86_64"]

  # Source from S3 (uploaded by modules/s3)
  s3_bucket        = var.artifacts_bucket_id
  s3_key           = var.lambda_s3_key
  source_code_hash = data.archive_file.lambda.output_base64sha256

  layers = [aws_lambda_layer_version.ddgs.arn]

  environment {
    variables = {
      PYTHONPATH = "/opt/python"
    }
  }

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]
}

# ------------------------------------------------------------------------------
# IAM role — GatewayAgentCoreRole (trusted by bedrock-agentcore, invokes Lambda)
# ------------------------------------------------------------------------------
resource "aws_iam_role" "gateway_agentcore" {
  name = "${var.name_prefix}-gateway-agentcore-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock-agentcore.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "gateway_agentcore_invoke_lambda" {
  name = "invoke-customer-support-lambda"
  role = aws_iam_role.gateway_agentcore.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "InvokeFunction"
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = [aws_lambda_function.customer_support.arn]
    }]
  })
}

# Grants the gateway role access to the AgentCore Policy Engine, required to
# attach/enforce policies (modules/bedrock_agentcore_gateway).
resource "aws_iam_role_policy" "gateway_agentcore_policy_engine_access" {
  name = "PolicyEngineAccess"
  role = aws_iam_role.gateway_agentcore.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["bedrock-agentcore:*"]
      Resource = [
        "arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:policy-engine/*",
        "arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:gateway/*",
      ]
    }]
  })
}

# ------------------------------------------------------------------------------
# SSM Parameters — Lambda ARN and gateway role ARN for agent runtime
# ------------------------------------------------------------------------------
resource "aws_ssm_parameter" "lambda_arn" {
  name        = "/app/customersupport/agentcore/lambda_arn"
  type        = "String"
  value       = aws_lambda_function.customer_support.arn
  description = "ARN of the lambda that integrates with agentcore"
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

resource "aws_ssm_parameter" "gateway_iam_role" {
  name        = "/app/customersupport/agentcore/gateway_iam_role"
  type        = "String"
  value       = aws_iam_role.gateway_agentcore.arn
  description = "AgentCore gateway IAM role ARN"
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}
