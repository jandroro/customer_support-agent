# ──────────────────────────────────────────────────────────────────────────────
# IAM managed policy for the Bedrock AgentCore customer-support agent.
#
# The policy is intentionally broad to allow full lifecycle management of the
# agent stack (deploy, operate, observe, tear down) while explicitly denying:
#   - Oversized EC2 instance types
#   - Reserved capacity purchases (cost guardrail)
#   - Deprecated / non-approved Bedrock foundation models
# ──────────────────────────────────────────────────────────────────────────────

# ------------------------------------------------------------------------------
# Policy document — built with the native data source so Terraform can validate
# it at plan time and produce clean diffs when individual statements change.
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "customer_support_agent" {

  # ---------------------------------------------------------------------------
  # ALLOW — Core AWS services required to provision and run the agent stack
  # ---------------------------------------------------------------------------
  statement {
    sid    = "CoreAWSServices"
    effect = "Allow"
    actions = [
      "aws-marketplace:Unsubscribe",
      "aws-marketplace:ViewSubscriptions",
      "cloudformation:*",
      "cloudtrail:*",
      "cloudwatch:*",
      "cognito-identity:*",
      "dynamodb:*",
      "es:*",
      "events:*",
      "execute-api:*",
      "lambda:*",
      "logs:*",
      "s3:*",
      "ecr:*",
      "sagemaker:*",
      "sts:*",
      "tag:*",
      "xray:*",
      "codebuild:*",
      "cognito-idp:*",
      "ssm:*",
      "secretsmanager:*",
    ]
    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # ALLOW — Full CRUD on Bedrock AgentCore resources
  # ---------------------------------------------------------------------------
  statement {
    sid    = "BedrockAgentCorePermission"
    effect = "Allow"
    actions = [
      "bedrock-agentcore:Get*",
      "bedrock-agentcore:List*",
      "bedrock-agentcore:Delete*",
      "bedrock-agentcore:Create*",
      "bedrock-agentcore:Retrieve*",
      "bedrock-agentcore:Invoke*",
      "bedrock-agentcore:UpdateAgentRuntime",
      "bedrock-agentcore:ConnectBrowserAutomationStream",
      "bedrock-agentcore:ConnectBrowserLiveViewStream",
      "bedrock-agentcore:DeleteBrowser",
    ]
    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # ALLOW — ECR image pull (needed by AgentCore runtime to fetch agent images)
  # ---------------------------------------------------------------------------
  statement {
    sid    = "ECRAccess"
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # ALLOW — Workload access tokens (agent-to-agent and user-scoped auth)
  # ---------------------------------------------------------------------------
  statement {
    sid    = "BedrockAgentCoreWorkloadAccess"
    effect = "Allow"
    actions = [
      "bedrock-agentcore:GetWorkloadAccessToken",
      "bedrock-agentcore:GetWorkloadAccessTokenForJWT",
      "bedrock-agentcore:GetWorkloadAccessTokenForUserId",
    ]
    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # ALLOW — Application Signals discovery for AgentCore observability
  # ---------------------------------------------------------------------------
  statement {
    sid    = "BedrockAgentCoreObservability"
    effect = "Allow"
    actions = [
      "application-signals:StartDiscovery",
    ]
    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # ALLOW — Read-only Bedrock API access (model metadata, knowledge bases, etc.)
  # ---------------------------------------------------------------------------
  statement {
    sid    = "AmazonBedrockReadOnly"
    effect = "Allow"
    actions = [
      "bedrock:Get*",
      "bedrock:List*",
      "bedrock:PutUseCaseForModelAccess",
      "aws-marketplace:ViewSubscriptions",
    ]
    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # ALLOW — Minimal EC2 read needed for VPC/subnet lookups (no instance launch)
  # ---------------------------------------------------------------------------
  statement {
    sid    = "EC2Permissions"
    effect = "Allow"
    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
    ]
    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # ALLOW — Bedrock model invocation and marketplace entitlement management
  # ---------------------------------------------------------------------------
  statement {
    sid    = "BedrockPolicies"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:TagResource",
      "bedrock:UntagResource",
      "bedrock:ListFoundationModelAgreementOffers",
      "bedrock:PutFoundationModelEntitlement",
      "bedrock:CreateFoundationModelAgreement",
    ]
    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # ALLOW — AWS Marketplace model subscriptions scoped to approved product IDs
  # ---------------------------------------------------------------------------
  statement {
    sid    = "BedrockModelSubscriptions"
    effect = "Allow"
    actions = [
      "aws-marketplace:Subscribe",
      "aws-marketplace:Unsubscribe",
    ]
    resources = ["*"]

    # Restrict subscriptions to a pre-approved allowlist of Bedrock model listings
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws-marketplace:ProductId"
      values = [
        "prod-cx7ovbu5wex7g",
        "prod-5oba7y7jpji56",
        "prod-4dlfvry4v5hbi",
        "b7568428-a1ab-46d8-bab3-37def50f6f6a",
        "38e55671-c3fe-4a44-9783-3584906e7cad",
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # ALLOW — IAM role and policy management (agent execution roles, trust policies)
  # ---------------------------------------------------------------------------
  statement {
    sid    = "PassRoleToBedrock"
    effect = "Allow"
    actions = [
      "iam:*",
    ]
    resources = [
      "arn:aws:iam::*:role/*",
      "arn:aws:iam::*:policy/*",
    ]
  }

  # ---------------------------------------------------------------------------
  # ALLOW — Explicit PassRole grant (required when associating roles to services)
  # ---------------------------------------------------------------------------
  statement {
    sid    = "PassRole"
    effect = "Allow"
    actions = [
      "iam:PassRole",
    ]
    resources = ["arn:aws:iam::*:role/*"]
  }

  # ---------------------------------------------------------------------------
  # DENY — Block large and cost-prohibitive EC2 instance types
  # ---------------------------------------------------------------------------
  statement {
    sid    = "DenyXXLInstances"
    effect = "Deny"
    actions = [
      "ec2:RunInstances",
    ]
    resources = ["arn:aws:ec2:*:*:instance/*"]

    condition {
      test     = "StringLike"
      variable = "ec2:InstanceType"
      values = [
        "*6xlarge",
        "*8xlarge",
        "*10xlarge",
        "*12xlarge",
        "*16xlarge",
        "*18xlarge",
        "*24xlarge",
        "f1.4xlarge",
        "x1*",
        "z1*",
        "*metal",
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # DENY — Prevent accidental EC2 reserved-instance purchases
  # ---------------------------------------------------------------------------
  statement {
    sid    = "DontBuyEC2ReservationsPlz"
    effect = "Deny"
    actions = [
      "ec2:ModifyReservedInstances",
      "ec2:PurchaseHostReservation",
      "ec2:PurchaseReservedInstancesOffering",
      "ec2:PurchaseScheduledInstances",
    ]
    resources = ["arn:aws:ec2:*:*:*"]
  }

  # ---------------------------------------------------------------------------
  # DENY — Prevent accidental RDS reserved-instance purchases
  # ---------------------------------------------------------------------------
  statement {
    sid    = "DontBuyRDSReservationsPlz"
    effect = "Deny"
    actions = [
      "rds:PurchaseReservedDBInstancesOffering",
    ]
    resources = ["arn:aws:rds:*:*:*"]
  }

  # ---------------------------------------------------------------------------
  # DENY — Prevent accidental DynamoDB reserved-capacity purchases
  # ---------------------------------------------------------------------------
  statement {
    sid    = "DontBuyDynamodbReservationsPlz"
    effect = "Deny"
    actions = [
      "dynamodb:PurchaseReservedCapacityOfferings",
    ]
    resources = ["arn:aws:dynamodb:*:*:*"]
  }

  # ---------------------------------------------------------------------------
  # DENY — Block invocation of deprecated or non-approved Bedrock models.
  # Only Claude 3.5 / claude-sonnet-4-20250514 and Nova Pro/Lite (outside us-west-2)
  # are permitted through the Allow statements above.
  # ---------------------------------------------------------------------------
  statement {
    sid    = "DenyBedrockModelAccessForOtherModels"
    effect = "Deny"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:ListFoundationModelAgreementOffers",
      "bedrock:PutFoundationModelEntitlement",
      "bedrock:CreateFoundationModelAgreement",
    ]
    resources = [
      # Legacy Claude versions
      "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-opus-20240229-v1:0",
      "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
      "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-haiku-20240307-v1:0",
      "arn:aws:bedrock:*::foundation-model/anthropic.claude-sonnet-4-20250514-v1:0",
      "arn:aws:bedrock:*::foundation-model/anthropic.claude-v2:1",
      "arn:aws:bedrock:*::foundation-model/anthropic.claude-v2",
      "arn:aws:bedrock:*::foundation-model/anthropic.claude-instant-v1",
      # Nova Lite in us-west-2 only
      "arn:aws:bedrock:us-west-2::foundation-model/amazon.nova-2-lite-v1:0",
      # Third-party models not in scope for this project
      "arn:aws:bedrock:*::foundation-model/meta*",
      "arn:aws:bedrock:*::foundation-model/mistral*",
      "arn:aws:bedrock:*::foundation-model/cohere.*",
      "arn:aws:bedrock:*::foundation-model/stability*",
      "arn:aws:bedrock:*::foundation-model/amazon.titan-image-*",
      "arn:aws:bedrock:*::foundation-model/amazon.titan-embed-image-v1",
    ]
  }
}

# ------------------------------------------------------------------------------
# Managed policy — attached to deployer users/roles and AgentCore execution roles
# ------------------------------------------------------------------------------
resource "aws_iam_policy" "customer_support_agent" {
  name        = "${var.name_prefix}-policy"
  description = "Grants permissions required to deploy and operate the Bedrock AgentCore customer-support agent stack."
  policy      = data.aws_iam_policy_document.customer_support_agent.json

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Trust policy — allows SageMaker and CloudFormation to assume this role
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "lab_role_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["sagemaker.amazonaws.com"]
    }
  }

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["cloudformation.amazonaws.com"]
    }
  }
}

# ------------------------------------------------------------------------------
# IAM role — lab-customer-support-agent-role
# Trusted by SageMaker and CloudFormation; carries both the custom agent policy
# and the two AWS-managed policies required for the lab environment.
# ------------------------------------------------------------------------------
resource "aws_iam_role" "lab_customer_support_agent" {
  name               = "lab-customer-support-agent-role"
  assume_role_policy = data.aws_iam_policy_document.lab_role_trust.json
  description        = "Execution role for the Bedrock AgentCore customer-support lab environment."

  tags = var.tags
}

# Attach the custom managed policy defined above
resource "aws_iam_role_policy_attachment" "lab_custom_policy" {
  role       = aws_iam_role.lab_customer_support_agent.name
  policy_arn = aws_iam_policy.customer_support_agent.arn
}

# Attach AWS managed policy: AmazonSageMakerFullAccess
resource "aws_iam_role_policy_attachment" "lab_sagemaker_full_access" {
  role       = aws_iam_role.lab_customer_support_agent.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# Attach AWS managed policy: AmazonBedrockLimitedAccess
resource "aws_iam_role_policy_attachment" "lab_bedrock_limited_access" {
  role       = aws_iam_role.lab_customer_support_agent.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockLimitedAccess"
}

# ------------------------------------------------------------------------------
# IAM role — RuntimeAgentCoreRole
# Trusted by bedrock-agentcore.amazonaws.com; grants the agent container access
# to ECR, CloudWatch, X-Ray, Bedrock models, SSM parameters, and AgentCore APIs.
# ------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role" "runtime_agentcore" {
  name = "${var.name_prefix}-runtime-agentcore-role"

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

resource "aws_iam_role_policy" "runtime_agentcore" {
  name = "bedrock-agent-policy"
  role = aws_iam_role.runtime_agentcore.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRImageAccess"
        Effect   = "Allow"
        Action   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
        Resource = "arn:aws:ecr:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:repository/bedrock_agentcore-customersupport*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:DescribeLogStreams", "logs:CreateLogGroup"]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock-agentcore/runtimes/*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock-agentcore/runtimes/*:log-stream:*"
      },
      {
        Sid      = "ECRTokenAccess"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords", "xray:GetSamplingRules", "xray:GetSamplingTargets"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
        Condition = {
          StringEquals = { "cloudwatch:namespace" = "bedrock-agentcore" }
        }
      },
      {
        Sid    = "GetAgentAccessToken"
        Effect = "Allow"
        Action = ["bedrock-agentcore:GetWorkloadAccessToken", "bedrock-agentcore:GetWorkloadAccessTokenForJWT", "bedrock-agentcore:GetWorkloadAccessTokenForUserId"]
        Resource = [
          "arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:workload-identity-directory/default",
          "arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:workload-identity-directory/default/workload-identity/customersupport*",
        ]
      },
      {
        Sid    = "ProvisionedThroughputModelInvocation"
        Effect = "Allow"
        Action = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/*",
          "arn:aws:bedrock:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*",
        ]
      },
      {
        Sid      = "SSMGetparam"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/app/customersupport/*"
      },
      {
        Sid    = "Identity"
        Effect = "Allow"
        Action = ["bedrock-agentcore:GetResourceOauth2Token"]
        Resource = [
          "arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:token-vault/default/oauth2credentialprovider/customersupport*",
          "arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:workload-identity-directory/default/workload-identity/customersupport*",
          "arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:workload-identity-directory/default",
          "arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:token-vault/default",
        ]
      },
      {
        Sid      = "SecretManager"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:bedrock-agentcore-identity!default/oauth2/customersupport*"
      },
      {
        Sid    = "AgentCoreMemory"
        Effect = "Allow"
        Action = [
          "bedrock-agentcore:ListMemories",
          "bedrock-agentcore:ListMemoryRecords",
          "bedrock-agentcore:RetrieveMemoryRecords",
          "bedrock-agentcore:GetMemory",
          "bedrock-agentcore:GetMemoryRecord",
          "bedrock-agentcore:CreateEvent",
          "bedrock-agentcore:GetEvent",
        ]
        Resource = "arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:memory/customersupport*"
      },
    ]
  })
}

resource "aws_ssm_parameter" "runtime_iam_role" {
  name        = "/app/customersupport/agentcore/runtime_iam_role"
  type        = "String"
  value       = aws_iam_role.runtime_agentcore.arn
  description = "AgentCore runtime IAM role ARN"
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}
