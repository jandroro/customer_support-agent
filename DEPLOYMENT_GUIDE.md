# Customer Support Agent — Infrastructure as Code (Terraform)

## Getting Started with Amazon Bedrock AgentCore

This project is built on **Amazon Bedrock AgentCore**, a fully managed service that enables you to deploy and operate highly capable AI agents securely at scale. AgentCore provides purpose-built infrastructure for dynamic agent workloads, powerful tools to enhance agent capabilities, and essential enterprise controls for production deployment.

This repository implements a **Customer Support Agent** that demonstrates the full spectrum of AgentCore capabilities — from conversational AI grounded in a Knowledge Base, to enterprise-grade deployment with long-term memory, fine-grained authorization (Cedar policies), and observability.

### Business Scenario

You work for **TechCorp**, an e-commerce company that receives hundreds of customer support requests daily.

Customers contact support for various reasons:
- **Product Information** — getting specifications, pricing, and availability details
- **Policy Questions** — understanding return policies, shipping costs, and business hours
- **Warranty Status** — checking whether a product is still under warranty using its serial number
- **Technical Support** — troubleshooting product issues, with the option to search the web for up-to-date information

Currently, the support team spends significant time on repetitive tasks, leading to longer wait times and higher operational costs. This agent handles routine inquiries automatically — backed by a Knowledge Base, a DynamoDB-backed warranty lookup tool, and persistent memory of customer preferences — while the underlying infrastructure enforces authentication, authorization, and auditability suitable for production use.

---

## Requirements

| Tool | Minimum version |
|---|---|
| Terraform CLI | `>= 1.9` |
| AWS provider (`hashicorp/aws`) | `~> 6.0` |
| AWS Cloud Control provider (`hashicorp/awscc`) | `~> 1.0` |
| Docker with Buildx | any recent version |
| AWS CLI | v2 |

The `~> 6.0` AWS provider is required because the `aws_bedrockagentcore_*` resources (Runtime, Memory, Gateway, Gateway Target, Policy Engine, Policy) do not exist in `5.x`.

---

## Module structure

```
iac/
├── main.tf                    # Providers + module calls
├── variables.tf                # aws_profile, aws_region, project_name, environment, model_id
├── locals.tf                   # name_prefix + common tags
├── outputs.tf                  # Outputs from all modules
├── terraform.tfvars            # Local values (not committed)
├── terraform.tfvars.example    # Template for terraform.tfvars
└── modules/
    ├── iam/                         # Managed policy, lab role, AgentCore runtime IAM role
    ├── ecr/                         # ECR repository for the agent container image
    ├── s3/                          # Artifacts bucket + Knowledge Base data bucket
    ├── dynamodb/                    # Warranty + customer-profile tables (seeded with synthetic data)
    ├── lambda/                      # CustomerSupport tool Lambda + DDGS layer + Gateway IAM role
    ├── cognito/                     # Production User Pool (web + machine OAuth2 clients, hosted UI)
    ├── cognito_lab/                 # Isolated MCPServerPool for local/notebook MCP testing and per-user app login
    ├── bedrock_agentcore_gateway/   # MCP Gateway + Gateway Target + Policy Engine + Cedar policies
    ├── bedrock_kb/                  # S3 Vectors + Bedrock Knowledge Base + Data Source
    ├── bedrock_agentcore_memory/    # Long-term + short-term agent memory, with observability
    ├── bedrock_agentcore_runtime/   # IAM role + AgentCore Runtime (JWT-authorized), with observability
    ├── bedrock_agentcore_evaluation/ # Online Evaluation Config — continuous quality monitoring of the Runtime
    └── cloudwatch/                  # Log group + IAM role for Bedrock Model Invocation Logging
```

---

## Configuration

### Variables in `terraform.tfvars`

```hcl
aws_profile  = "<AWS CLI profile configured in ~/.aws/config>"
aws_region   = "<AWS region to deploy to, e.g. us-east-1>"
project_name = "customer-support-agent"
environment  = "dev"
model_id     = "<Bedrock model ID, e.g. us.anthropic.claude-sonnet-4-20250514-v1:0>"
```

Copy the example file and fill in your values:

```bash
cd iac/
cp terraform.tfvars.example terraform.tfvars
```

### Runtime environment variables

The AgentCore Runtime container (`src/customer_support_agent/main.py`) receives its configuration through environment variables injected by Terraform — no manual `.env` file or secrets are required for the base deployment:

| Variable | Source |
|---|---|
| `MODEL_ID` | `var.model_id` (from `terraform.tfvars`) |
| `AWS_DEFAULT_REGION` | `var.aws_region` |
| `MEMORY_ID` | `module.bedrock_agentcore_memory.memory_id` (wired automatically — Terraform creates Memory before Runtime) |

If you introduce a sensitive value in the future (an external API key, for example), follow the same pattern already used for `aws_profile`/`aws_region`: declare a `sensitive = true` Terraform variable and pass it via `TF_VAR_<name>` rather than committing it to `terraform.tfvars`.

---

## Deployment — Two-phase strategy

The AgentCore Runtime requires a container image to already exist in ECR at `apply` time. For this reason, deployment is split into two phases with a Docker build/push step in between.

### Phase 1 — Create the ECR repository (and the rest of the agent's dependencies)

The Runtime is the only resource that depends on the container image, so the first `apply` targets everything except it — this also builds DynamoDB tables, the Knowledge Base, Memory, the Gateway, and Cognito in one pass:

```bash
cd iac/
terraform init
terraform plan
terraform apply -target=module.ecr
```

### Build and push the image

> Replace `<AWS_ACCOUNT_ID>` with your numeric account ID (get it with `aws sts get-caller-identity --query Account --output text`).
> Replace `<AWS_PROFILE>` and `<AWS_REGION>` with the values from your `terraform.tfvars`.

Authenticate to ECR:

```bash
cd ..
aws ecr get-login-password --region <AWS_REGION> --profile <AWS_PROFILE> \
  | docker login --username AWS --password-stdin \
    <AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com
```

Create the Buildx builder if it doesn't already exist (needed for `--push` and `--platform`):

```bash
docker buildx create --use
```

Build and push (run from the project root, since the Dockerfile's build context is the repo root):

```bash
docker buildx build --platform linux/arm64 \
  -f docker/Dockerfile \
  -t <AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/customer-support-agent-dev-repo:latest \
  --push .
```

> The image name must match the ECR repository created in Phase 1 — check it with `terraform output ecr_repository_url`.

### Phase 2 — Deploy the rest of the infrastructure (AgentCore Runtime and its observability pipeline)

```bash
cd iac/
terraform plan
terraform apply
```

---

## Validate the image before applying (optional)

To avoid a `ValidationException: The specified image identifier does not exist` error, confirm the image exists in ECR before re-running `apply`:

```bash
aws ecr describe-images \
  --repository-name customer-support-agent-dev-repo \
  --image-ids imageTag=latest \
  --profile <AWS_PROFILE> \
  || { echo "ERROR: :latest image not found in ECR — push it first"; exit 1; }
```

---

## Resources created

| Module | AWS resource | Purpose |
|---|---|---|
| `iam` | `aws_iam_policy`, `aws_iam_role` | Deployer-scoped managed policy; lab role; runtime execution role |
| `ecr` | `aws_ecr_repository`, `aws_ecr_lifecycle_policy` | Agent container image registry (keeps last 5 images) |
| `s3` | `aws_s3_bucket` (x2) | Lambda artifacts bucket; Knowledge Base source-documents bucket |
| `dynamodb` | `aws_dynamodb_table` (x2) | `warranty` and `customer-profile` tables, seeded with synthetic data |
| `lambda` | `aws_lambda_function`, `aws_iam_role` | `CustomerSupport` tool function (warranty lookup, web search via DDGS layer) |
| `cognito` | `aws_cognito_user_pool`, clients, domain | Production User Pool — web (Auth Code) and machine (Client Credentials) OAuth2 clients |
| `cognito_lab` | `aws_cognito_user_pool`, client, secret | `MCPServerPool` — isolated pool for local/notebook MCP testing and the frontend/backend's per-user register/login (`USER_PASSWORD_AUTH`/SRP) |
| `bedrock_agentcore_gateway` | `aws_bedrockagentcore_gateway`, `_gateway_target`, `_policy_engine`, `_policy` | MCP Gateway exposing the Lambda as a tool; Cedar authorization policies in `ENFORCE` mode |
| `bedrock_kb` | `aws_bedrockagentcore_*` (S3 Vectors), Knowledge Base, Data Source | Product/policy document retrieval for the agent |
| `bedrock_agentcore_memory` | `aws_bedrockagentcore_memory`, `_memory_strategy` | User-preference and semantic memory strategies, with CloudWatch/X-Ray observability |
| `bedrock_agentcore_runtime` | `aws_bedrockagentcore_agent_runtime`, `aws_iam_role` | The deployed agent container, authorized via a `CUSTOM_JWT` authorizer against `MCPServerPool`; vended `APPLICATION_LOGS`/`USAGE_LOGS` delivery. No explicit `_endpoint` resource — invocations target the `DEFAULT` endpoint AWS creates automatically with every Runtime |
| `bedrock_agentcore_evaluation` | `aws_bedrockagentcore_online_evaluation_config`, `aws_iam_role` | Continuous online evaluation of the Runtime's `DEFAULT` endpoint (built-in evaluators: goal success rate, correctness, tool selection accuracy) |
| `cloudwatch` | `aws_cloudwatch_log_group`, `aws_iam_role` | Destination + role for Bedrock Model Invocation Logging (configured manually in the console) |

---

## Main outputs

```bash
terraform output ecr_repository_url             # ECR repository URL (build/push target)
terraform output agentcore_runtime_id           # AgentCore Runtime ID
terraform output agentcore_runtime_arn          # AgentCore Runtime ARN
terraform output gateway_id                     # AgentCore Gateway ID
terraform output gateway_url                    # MCP Gateway endpoint URL
terraform output policy_engine_id               # AgentCore Policy Engine ID
terraform output agentcore_memory_id            # AgentCore Memory ID
terraform output knowledge_base_id              # Bedrock Knowledge Base ID
terraform output online_evaluation_config_id    # Online Evaluation Config ID
terraform output cognito_domain                 # Production Cognito hosted-UI URL
terraform output mcp_lab_pool_id                # MCPServerPool ID (lab/testing + app login)
```

---

## Common errors

### `aws_bedrockagentcore_*` resource not recognized

The installed provider is `5.x`. Remove the lock file and reinitialize:

```bash
rm .terraform.lock.hcl
terraform init
```

### `The specified image identifier does not exist`

The `:latest` image hasn't been pushed to ECR yet. Run Phase 1 and the build/push step before re-running `terraform apply`.

### `The security token included in the request is invalid`

The AWS profile isn't active or credentials expired. Check with:

```bash
aws sts get-caller-identity --profile <AWS_PROFILE>
```

If using SSO: `aws sso login --profile <AWS_PROFILE>`

### `ConflictException` on `aws_bedrockagentcore_policy_engine` / `aws_bedrockagentcore_policy`

Bedrock AgentCore's control plane has occasional eventual-consistency lag right after a name becomes free (e.g., after deleting a previous resource with the same name). Re-running `terraform apply` (or a targeted apply on just that resource) typically resolves it. If a policy is left in `CREATE_FAILED` state in AWS but is **not** picked up cleanly on retry, delete it directly via the AWS CLI/SDK and remove it from Terraform state (`terraform state rm <address>`) before reapplying.

### `401`/`403` invoking the Runtime or the Gateway

Both `module.bedrock_agentcore_runtime` and `module.bedrock_agentcore_gateway` set a `custom_jwt_authorizer` (`allowed_clients`/`discovery_url`) trusting only `MCPServerPool` (`module.cognito_lab`) — **not** the production pool (`module.cognito`). A `401`/`403` almost always means the bearer token in the `Authorization` header was issued by the wrong pool, or has expired. Make sure the token you pass was minted against `MCPServerPool` — either the backend's shared service identity (`backend/app/services/cognito_auth.py`) or a real user's own token from `/api/auth/login`.

---

## Tearing down

`terraform destroy` from `iac/` removes everything in the table above — but two resource types aren't configured with `force_destroy`/`force_delete`, so destroy fails partway through unless they're emptied first:

- **S3 buckets** (`artifacts`, `kb-data`) — the `artifacts` bucket has versioning enabled, so every noncurrent object version and delete marker has to be deleted too, not just the current version.
- **ECR repository** — fails if any image is still pushed there (every image built and pushed during deployment).

`src/notebooks/lab-07-cleanup.ipynb` automates both of these (reading bucket/repository names from Terraform's own outputs) before running `terraform destroy` and verifying the stack is gone.
