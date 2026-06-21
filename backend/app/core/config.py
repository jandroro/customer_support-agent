"""Application settings, loaded from config.yaml with environment variable
overrides.

Import the module-level `settings` singleton wherever configuration is
needed — do not instantiate `Settings()` again, since construction re-reads
config.yaml and the environment.
"""

import os
from typing import Optional
from pydantic import BaseModel
from pydantic_settings import (
    BaseSettings,
    PydanticBaseSettingsSource,
    SettingsConfigDict,
    YamlConfigSettingsSource,
)


class AwsConfig(BaseModel):
    """AWS session parameters shared by every boto3 client in this app.

    Attributes:
        region: AWS region used for all SDK calls.
        profile: AWS CLI profile name for local development. Leave `None`
            when running inside AWS (ECS/EC2/Lambda) so boto3 falls back to
            the attached IAM role.
    """

    region: str = "us-east-1"
    profile: Optional[str] = None


class AgentCoreConfig(BaseModel):
    """Locates the deployed Bedrock AgentCore Runtime.

    Attributes:
        runtime_arn_ssm_parameter: SSM parameter name (published by
            Terraform) holding the Runtime ARN to invoke.
        endpoint_name: Runtime endpoint qualifier to invoke.
    """

    runtime_arn_ssm_parameter: str = "/app/customersupport/agentcore/runtime_arn"
    endpoint_name: str = "DEFAULT"


class CognitoConfig(BaseModel):
    """MCPServerPool Cognito settings — the only user pool the Runtime/Gateway
    CUSTOM_JWT authorizer trusts.

    Attributes:
        pool_id_ssm_parameter: SSM parameter name holding the pool ID.
        client_id_ssm_parameter: SSM parameter name holding the app client ID.
        client_secret_ssm_parameter: SSM parameter name holding the app
            client secret.
        discovery_url_ssm_parameter: SSM parameter name holding the OIDC
            discovery URL.
        test_username: Username of the shared lab/demo service identity.
        test_password: Password of the shared lab/demo service identity.
            Matches the credential already used across this project's
            notebooks (get_or_create_cognito_pool). Override via the
            COGNITO__TEST_PASSWORD env var rather than editing config.yaml.
    """

    pool_id_ssm_parameter: str
    client_id_ssm_parameter: str
    client_secret_ssm_parameter: str
    discovery_url_ssm_parameter: str
    test_username: str = "testuser"
    test_password: str = "MyPassword123!"  # pragma: allowlist secret


class AgentConfig(BaseModel):
    """Defaults applied when a chat request doesn't specify its own identity.

    Attributes:
        default_actor_id: AgentCore Memory actor_id used when no logged-in
            user (and thus no per-user actor_id) is present on the request.
    """

    default_actor_id: str = "customer_001"


class CorsConfig(BaseModel):
    """Cross-Origin Resource Sharing settings for the FastAPI app.

    Attributes:
        allowed_origins: Origins allowed to call this API (e.g. the
            frontend's URL).
    """

    allowed_origins: list[str] = ["http://localhost:3000"]


class Settings(BaseSettings):
    """Root settings object, assembled from config.yaml and environment
    variables.

    Attributes:
        aws: AWS session parameters.
        agentcore: Bedrock AgentCore Runtime location.
        cognito: MCPServerPool Cognito settings.
        agent: Chat request defaults.
        cors: CORS configuration.
    """

    aws: AwsConfig = AwsConfig()
    agentcore: AgentCoreConfig = AgentCoreConfig()
    cognito: CognitoConfig
    agent: AgentConfig = AgentConfig()
    cors: CorsConfig = CorsConfig()

    model_config = SettingsConfigDict(
        yaml_file=os.environ.get("CONFIG_FILE", "config.yaml"),
        env_nested_delimiter="__",
        env_file=".env",
        extra="ignore",
    )

    @classmethod
    def settings_customise_sources(
        cls,
        settings_cls: type[BaseSettings],
        init_settings: PydanticBaseSettingsSource,
        env_settings: PydanticBaseSettingsSource,
        dotenv_settings: PydanticBaseSettingsSource,
        file_secret_settings: PydanticBaseSettingsSource,
    ) -> tuple[PydanticBaseSettingsSource, ...]:
        """Defines the precedence used to resolve each setting.

        Order (highest to lowest precedence): environment variables, `.env`
        file, `config.yaml`, constructor defaults, secrets file.

        Args:
            settings_cls: The `Settings` class being configured.
            init_settings: Source reading values passed to `Settings(...)`.
            env_settings: Source reading process environment variables.
            dotenv_settings: Source reading the `.env` file.
            file_secret_settings: Source reading Docker/Kubernetes secret files.

        Returns:
            The settings sources in priority order (first wins).
        """
        return (
            env_settings,
            dotenv_settings,
            YamlConfigSettingsSource(settings_cls),
            init_settings,
            file_secret_settings,
        )


settings = Settings()
"""Process-wide settings singleton — import this, don't instantiate `Settings()` again."""
