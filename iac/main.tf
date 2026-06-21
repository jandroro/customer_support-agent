provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

provider "awscc" {
  profile = var.aws_profile
  region  = var.aws_region
}

# Source paths — resolved from the repo root so modules receive absolute paths
locals {
  lambda_source_path  = "${path.root}/../src/lambda/python"
  ddgs_layer_zip_path = "${path.root}/../src/lambda/layers/ddgs-layer.zip"
}

# ──────────────────────────────────────────────────────────────────────────────
# IAM — managed policy, lab role, and AgentCore runtime role
# ──────────────────────────────────────────────────────────────────────────────
module "iam" {
  source = "./modules/iam"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# ECR — repository and images
# ──────────────────────────────────────────────────────────────────────────────

module "ecr" {
  source = "./modules/ecr"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# S3 — artifacts bucket (Lambda code) + Knowledge Base data bucket
# ──────────────────────────────────────────────────────────────────────────────
module "s3" {
  source = "./modules/s3"

  name_prefix         = local.name_prefix
  lambda_zip_path     = data.archive_file.lambda.output_path
  ddgs_layer_zip_path = local.ddgs_layer_zip_path
  tags                = local.common_tags
}

# Lambda zip is built here at the root so both modules/s3 and modules/lambda
# can reference the same output_path without re-archiving.
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = local.lambda_source_path
  output_path = "${path.root}/.build/lambda.zip"
  excludes    = ["ddgs-layer.zip", "__pycache__"]
}

# ──────────────────────────────────────────────────────────────────────────────
# DynamoDB — warranty + customer-profile tables with synthetic seed data
# ──────────────────────────────────────────────────────────────────────────────
module "dynamodb" {
  source = "./modules/dynamodb"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Lambda — CustomerSupport function, DDGS layer, execution roles
# ──────────────────────────────────────────────────────────────────────────────
module "lambda" {
  source = "./modules/lambda"

  name_prefix                = local.name_prefix
  lambda_source_path         = local.lambda_source_path
  ddgs_layer_zip_path        = local.ddgs_layer_zip_path
  artifacts_bucket_id        = module.s3.artifacts_bucket_id
  lambda_s3_key              = module.s3.lambda_s3_key
  warranty_table_arn         = module.dynamodb.warranty_table_arn
  customer_profile_table_arn = module.dynamodb.customer_profile_table_arn
  tags                       = local.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Cognito — User Pool, clients, hosted-UI domain, PostSignup Lambda
# ──────────────────────────────────────────────────────────────────────────────
module "cognito" {
  source = "./modules/cognito"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Cognito Lab — isolated MCPServerPool for local/notebook MCP server testing
# ──────────────────────────────────────────────────────────────────────────────
module "cognito_lab" {
  source = "./modules/cognito_lab"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Bedrock AgentCore Gateway — MCP endpoint authorized via the MCPServerPool
# Cognito client (modules/cognito_lab). Also includes the Policy Engine and
# Cedar policies (kept in this module to avoid a gateway<->policy-engine
# circular dependency between modules).
# ──────────────────────────────────────────────────────────────────────────────
module "bedrock_agentcore_gateway" {
  source = "./modules/bedrock_agentcore_gateway"

  gateway_role_arn  = module.lambda.gateway_agentcore_role_arn
  allowed_client_id = module.cognito_lab.client_id
  discovery_url     = module.cognito_lab.discovery_url
  lambda_arn        = module.lambda.lambda_arn
  tags              = local.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Bedrock Knowledge Base — S3 Vectors + KB + Data Source + docs upload
# ──────────────────────────────────────────────────────────────────────────────
module "bedrock_kb" {
  source = "./modules/bedrock_kb"

  kb_data_bucket_id  = module.s3.kb_data_bucket_id
  kb_data_bucket_arn = module.s3.kb_data_bucket_arn
  tags               = local.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Bedrock AgentCore Memory — long-term + short-term memory for the agent
# ──────────────────────────────────────────────────────────────────────────────
module "bedrock_agentcore_memory" {
  source = "./modules/bedrock_agentcore_memory"

  tags = local.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Bedrock AgentCore Runtime
# ──────────────────────────────────────────────────────────────────────────────

module "bedrock_agentcore_runtime" {
  source = "./modules/bedrock_agentcore_runtime"

  name_prefix         = local.name_prefix
  container_image_uri = "${module.ecr.repository_url}:latest"
  ecr_repository_arn  = module.ecr.repository_arn
  allowed_client_id   = module.cognito_lab.client_id
  discovery_url       = module.cognito_lab.discovery_url
  environment_variables = {
    MODEL_ID           = var.model_id
    AWS_DEFAULT_REGION = var.aws_region
    MEMORY_ID          = module.bedrock_agentcore_memory.memory_id
  }

  tags = local.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Bedrock AgentCore Online Evaluation — continuous quality monitoring for the
# deployed Runtime. Targets the "DEFAULT" endpoint specifically, since that's
# the one backend/notebooks actually invoke (endpoint_name="DEFAULT" default
# everywhere) — not the explicit aws_bedrockagentcore_agent_runtime_endpoint
# resource below, which currently receives no real traffic.
# ──────────────────────────────────────────────────────────────────────────────
module "bedrock_agentcore_evaluation" {
  source = "./modules/bedrock_agentcore_evaluation"

  name_prefix = local.name_prefix
  runtime_id  = module.bedrock_agentcore_runtime.runtime_id
  tags        = local.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# CloudWatch — log group + IAM role for Bedrock Model Invocation Logging
# ──────────────────────────────────────────────────────────────────────────────
module "cloudwatch" {
  source = "./modules/cloudwatch"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}