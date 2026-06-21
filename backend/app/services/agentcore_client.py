"""Invokes the Bedrock AgentCore Runtime over its data-plane HTTP API,
mirroring the invoke_runtime() helper used in notebooks/lab-04-agentcore-runtime.ipynb
(itself a reimplementation of bedrock_agentcore_starter_toolkit's
HttpBedrockAgentCoreClient.invoke_endpoint, without the toolkit's dependency
on a local .bedrock_agentcore.yaml config file).
"""

import json
import urllib.parse
from typing import Optional

import httpx

from ..core.config import settings
from ..utils.aws import get_boto_session

_runtime_arn_cache: Optional[str] = None


def get_runtime_arn() -> str:
    """Return the deployed Runtime ARN.

    Read from SSM (published by Terraform after `apply`) on first call and
    cached in memory for the lifetime of the process — the Runtime ARN
    doesn't change without a redeploy, which would also restart this service.

    Returns:
        The AgentCore Runtime ARN to invoke.
    """
    global _runtime_arn_cache
    if _runtime_arn_cache is None:
        ssm = get_boto_session().client("ssm")
        _runtime_arn_cache = ssm.get_parameter(Name=settings.agentcore.runtime_arn_ssm_parameter)["Parameter"][
            "Value"
        ]
    return _runtime_arn_cache


def _data_plane_endpoint() -> str:
    """Build the regional Bedrock AgentCore data-plane base URL."""
    return f"https://bedrock-agentcore.{settings.aws.region}.amazonaws.com"


def _normalize_agent_text(raw: str) -> str:
    """Unwrap the Runtime's JSON-encoded text response body.

    The Runtime returns the agent's plain-text response JSON-encoded as a
    string body. Prefers `json.loads` (correctly unescapes and strips
    quotes); falls back to a manual unescape if the body isn't valid JSON.

    Args:
        raw: The raw HTTP response body text.

    Returns:
        The agent's plain-text response.
    """
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, str):
            return parsed
    except (ValueError, TypeError):
        pass
    return raw.replace("\\n", "\n")


async def invoke_agent(prompt: str, actor_id: str, session_id: str, bearer_token: str) -> str:
    """Invoke the Bedrock AgentCore Runtime and return the agent's text response.

    Args:
        prompt: The user's message.
        actor_id: AgentCore Memory identity to associate with this turn.
        session_id: AgentCore session id — continues an existing conversation
            or starts a new one.
        bearer_token: JWT sent as the Authorization header; must be issued by
            MCPServerPool (the pool the Runtime's CUSTOM_JWT authorizer trusts).

    Returns:
        The agent's plain-text response.

    Raises:
        httpx.HTTPStatusError: If the Runtime returns a non-2xx response
            (e.g. 401/403 for an invalid/expired token).
    """
    runtime_arn = get_runtime_arn()
    url = f"{_data_plane_endpoint()}/runtimes/{urllib.parse.quote(runtime_arn, safe='')}/invocations"
    headers = {
        "Content-Type": "application/json",
        "X-Amzn-Bedrock-AgentCore-Runtime-Session-Id": session_id,
        "Authorization": f"Bearer {bearer_token}",
    }
    payload = {"prompt": prompt, "actor_id": actor_id}

    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.post(
            url,
            params={"qualifier": settings.agentcore.endpoint_name},
            headers=headers,
            json=payload,
        )
    response.raise_for_status()
    return _normalize_agent_text(response.text)
