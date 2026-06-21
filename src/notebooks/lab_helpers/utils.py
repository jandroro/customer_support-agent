import base64
import hashlib
import hmac
import json
from .aws_clients import (
    REGION,
    sts_client,
    ssm_client,
    cognito_client,
    secrets_client,
    iam_client,
)
from .config import (
    COGNITO_USERNAME,
    COGNITO_PASSWORD,
    SM_NAME,
)


# =====================================================
# LOCAL VARIABLES
# =====================================================

role_name = f"CustomerSupportAssistantBedrockAgentCoreRole-{REGION}"
policy_name = f"CustomerSupportAssistantBedrockAgentCorePolicy-{REGION}"


# =====================================================
# LOCAL METHODS
# =====================================================

def load_api_spec(file_path: str) -> list:
    with open(file_path, "r") as f:
        data = json.load(f)
    if not isinstance(data, list):
        raise ValueError("Expected a list in the JSON file")
    return data


# =====================================================
# STS
# =====================================================

def get_aws_account_id() -> str:
    return sts_client.get_caller_identity()["Account"]


# =====================================================
# PARAMETER STORE
# =====================================================

def get_ssm_parameter(name: str, with_decryption: bool = True) -> str:
    response = ssm_client.get_parameter(Name=name, WithDecryption=with_decryption)
    return response["Parameter"]["Value"]


def put_ssm_parameter(name: str, value: str, parameter_type: str = "String", with_encryption: bool = False) -> None:
    put_params = {
        "Name": name,
        "Value": value,
        "Type": parameter_type,
        "Overwrite": True,
    }

    if with_encryption:
        put_params["Type"] = "SecureString"

    ssm_client.put_parameter(**put_params)


# =====================================================
# SECRETS MANAGER
# =====================================================

def get_customer_support_secret():
    """Get a secret value from AWS Secrets Manager."""
    try:
        response = secrets_client.get_secret_value(SecretId=SM_NAME)
        return response["SecretString"]
    except Exception as e:
        print(f"Error getting secret: {str(e)}")
        return None


# =====================================================
# COGNITO
# =====================================================

def reauthenticate_user(client_id, client_secret):
    # Authenticate User and get Access Token
    message = bytes(COGNITO_USERNAME + client_id, "utf-8")
    key = bytes(client_secret, "utf-8")
    secret_hash = base64.b64encode(hmac.new(key, message, digestmod=hashlib.sha256).digest()).decode()

    auth_response = cognito_client.initiate_auth(
        ClientId=client_id,
        AuthFlow="USER_PASSWORD_AUTH",
        AuthParameters={
            "USERNAME": COGNITO_USERNAME,
            "PASSWORD": COGNITO_PASSWORD,  # pragma: allowlist secret
            "SECRET_HASH": secret_hash,
        },
    )
    bearer_token = auth_response["AuthenticationResult"]["AccessToken"]
    return bearer_token


def save_customer_support_secret(secret_value):
    """Save a secret in AWS Secrets Manager."""
    try:
        secrets_client.create_secret(
            Name=SM_NAME,
            SecretString=secret_value,
            Description="Secret containing the Cognito Configuration for the Customer Support Agent",
        )
        print("✅ Created secret")
    except secrets_client.exceptions.ResourceExistsException:
        secrets_client.update_secret(SecretId=SM_NAME, SecretString=secret_value)
        print("✅ Updated existing secret")
    except Exception as e:
        print(f"❌ Error saving secret: {str(e)}")
        return False
    return True


def get_or_create_cognito_pool(refresh_token=False):
    try:
        # check for existing cognito pool
        cognito_config_str = get_customer_support_secret()
        cognito_config = json.loads(cognito_config_str)
        
        if refresh_token:
            cognito_config["bearer_token"] = reauthenticate_user(
                cognito_config["client_id"],
                cognito_config["client_secret"]
            )
        return cognito_config
    except Exception:
        print("No existing cognito config found. Creating a new one..")

    try:
        # Pool and client are provisioned by Terraform (modules/cognito_lab);
        # this helper only manages the test user and the runtime bearer token.
        pool_id = get_ssm_parameter("/app/customersupport/agentcore/mcp_lab/pool_id", with_decryption=False)
        client_id = get_ssm_parameter("/app/customersupport/agentcore/mcp_lab/client_id", with_decryption=False)
        client_secret = get_ssm_parameter("/app/customersupport/agentcore/mcp_lab/client_secret")
        discovery_url = get_ssm_parameter(
            "/app/customersupport/agentcore/mcp_lab/cognito_discovery_url", with_decryption=False
        )

        # Create User (idempotent — skip if it already exists)
        try:
            cognito_client.admin_create_user(
                UserPoolId=pool_id,
                Username=COGNITO_USERNAME,
                TemporaryPassword="Temp123!",  # pragma: allowlist secret
                MessageAction="SUPPRESS",
            )
        except cognito_client.exceptions.UsernameExistsException:
            print(f"ℹ️ User {COGNITO_USERNAME} already exists")

        # Set Permanent Password
        cognito_client.admin_set_user_password(
            UserPoolId=pool_id,
            Username=COGNITO_USERNAME,
            Password=COGNITO_PASSWORD,  # pragma: allowlist secret
            Permanent=True,
        )

        message = bytes(COGNITO_USERNAME + client_id, "utf-8")
        key = bytes(client_secret, "utf-8")
        secret_hash = base64.b64encode(hmac.new(key, message, digestmod=hashlib.sha256).digest()).decode()

        # Authenticate User and get Access Token
        auth_response = cognito_client.initiate_auth(
            ClientId=client_id,
            AuthFlow="USER_PASSWORD_AUTH",
            AuthParameters={
                "USERNAME": COGNITO_USERNAME,
                "PASSWORD": COGNITO_PASSWORD,  # pragma: allowlist secret
                "SECRET_HASH": secret_hash,
            },
        )
        bearer_token = auth_response["AuthenticationResult"]["AccessToken"]

        # Output the required values
        print(f"Pool id: {pool_id}")
        print(f"Discovery URL: {discovery_url}")
        print(f"Client ID: {client_id}")
        print(f"Bearer Token: {bearer_token}")

        # Return values if needed for further processing
        cognito_config = {
            "pool_id": pool_id,
            "client_id": client_id,
            "client_secret": client_secret,
            "secret_hash": secret_hash,
            "bearer_token": bearer_token,
            "discovery_url": discovery_url,
        }

        save_customer_support_secret(json.dumps(cognito_config))

        return cognito_config
    except Exception as e:
        print(f"Error: {e}")
        return None
