import os
from boto3.session import Session


# =====================================================
# BOTO3 SESSION
# =====================================================

# Use AWS_PROFILE only when explicitly set (local development).
# Inside the AgentCore Runtime container there is no profile configured;
# credentials are provided automatically via the execution role.
boto_session = Session(profile_name=os.environ.get("AWS_PROFILE"))


# =====================================================
# BOTO3 CLIENTS
# =====================================================

sts_client = boto_session.client("sts")
ssm_client = boto_session.client("ssm")
agentcore_control_client = boto_session.client("bedrock-agentcore-control")


# =====================================================
# ACCOUNT DETAILS
# =====================================================

# Get the Account ID
ACCOUNT_ID = sts_client.get_caller_identity()["Account"]

# Get AWS account details
REGION = boto_session.region_name