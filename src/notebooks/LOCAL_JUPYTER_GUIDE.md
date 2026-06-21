# Local JupyterLab Environment Quick Start Guide

Follow these instructions to run the lab notebooks (`lab-01` through `lab-05`) locally from this repository. Unlike the original AWS workshop, you do **not** need to clone a separate samples repository — everything lives in this project (`customer_support`), and the AWS infrastructure (DynamoDB, Cognito, Lambda, Bedrock Knowledge Base, AgentCore Gateway/Memory/Runtime) is provisioned by **Terraform**, not a `prereq.sh` script.

1. Open a terminal at the **repository root** (`customer_support/`) — this is where `pyproject.toml`, `uv.lock`, and `.python-version` already live.
2. Install the prerequisites for deploying the agent to AgentCore Runtime:
   - AWS CLI v2, configured with a named profile (`aws configure --profile <your-profile>`)
   - Docker (used to build/push the agent's container image — see `DEPLOYMENT_GUIDE.md`)
   - [uv](https://docs.astral.sh/uv/getting-started/installation/), a fast Python package/project manager
3. Create and activate the project's virtual environment from the repository root:

   ```bash
   uv python install 3.12
   uv venv
   source .venv/bin/activate   # on Windows: .venv\Scripts\activate.bat
   ```

4. Install the notebook dependencies into that environment:

   ```bash
   uv pip install -r src/notebooks/requirements.txt
   ```

5. Provision the AWS infrastructure the notebooks depend on (DynamoDB tables, Cognito `MCPServerPool`, the warranty/web-search Lambda, the Bedrock Knowledge Base, AgentCore Gateway/Memory/Runtime). This is the Terraform stack in `iac/` — follow the full two-phase walkthrough in **[`DEPLOYMENT_GUIDE.md`](../../DEPLOYMENT_GUIDE.md)** at the repository root:

   ```bash
   cd iac
   cp terraform.tfvars.example terraform.tfvars   # fill in your AWS profile, region, model ID
   terraform init
   terraform apply -target=module.ecr
   # build & push the agent image — see DEPLOYMENT_GUIDE.md
   terraform apply
   cd ..
   ```

6. Start JupyterLab from the activated environment:

   ```bash
   uv run --with jupyter jupyter lab src/notebooks
   ```

   You should see `lab-01-create-an-agent.ipynb` through `lab-05-agentcore-evals.ipynb`. Run them in order — each one reads the resource identifiers it needs (pool IDs, Gateway URL, Runtime ARN, etc.) from SSM parameters published by `terraform apply`.

**Note:** Python version must be `>= 3.12` (see `.python-version` at the repository root).
