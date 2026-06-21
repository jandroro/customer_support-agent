"""Chat endpoint — proxies messages to the Bedrock AgentCore Runtime."""

import logging
import uuid
import httpx
from fastapi import APIRouter, HTTPException
from ...core.config import settings
from ...models.chat import ChatRequest, ChatResponse
from ...services import agentcore_client, cognito_auth


logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["Chat"])


@router.post(
    "/chat",
    response_model=ChatResponse,
    summary="Send a message to the Customer Support Agent",
    responses={502: {"description": "The Bedrock AgentCore Runtime invocation failed"}},
)
async def chat(request: ChatRequest) -> ChatResponse:
    """Proxy a chat message to the Bedrock AgentCore Runtime.

    If `access_token` is provided (a logged-in user), it's used directly as
    the AgentCore JWT and `actor_id` defaults to the user's username for
    Memory personalization. Otherwise falls back to the shared service
    identity (`testuser`), with one automatic retry on a stale cached token.

    Args:
        request: The chat message, optional session/actor ids, and optional
            per-user access token.

    Returns:
        The agent's response, along with the session_id and actor_id used
        for this turn (echoed back so the caller can reuse them).

    Raises:
        HTTPException: 502 if the Runtime invocation fails (including after
            a token-refresh retry for the shared identity).
    """
    session_id = request.session_id or str(uuid.uuid4())

    # A logged-in user's own JWT takes priority over the shared service
    # identity, both for AgentCore auth and for the Memory actor_id.
    if request.access_token:
        bearer_token = request.access_token
        actor_id = request.actor_id or "unknown_user"
    else:
        bearer_token = cognito_auth.get_bearer_token()
        actor_id = request.actor_id or settings.agent.default_actor_id

    try:
        raw_response = await agentcore_client.invoke_agent(
            prompt=request.message,
            actor_id=actor_id,
            session_id=session_id,
            bearer_token=bearer_token,
        )
    except httpx.HTTPStatusError as exc:
        if exc.response.status_code in (401, 403) and not request.access_token:
            # Cached shared-identity JWT likely went stale — retry once. A
            # logged-in user's own token can't be silently refreshed here
            # (no refresh_token in this request) — the frontend handles that.
            logger.warning("Agent invocation got %s, retrying with a fresh token", exc.response.status_code)
            bearer_token = cognito_auth.get_bearer_token(force_refresh=True)
            try:
                raw_response = await agentcore_client.invoke_agent(
                    prompt=request.message,
                    actor_id=actor_id,
                    session_id=session_id,
                    bearer_token=bearer_token,
                )
            except httpx.HTTPStatusError as retry_exc:
                logger.exception("Agent invocation failed after token refresh")
                raise HTTPException(
                    status_code=502, detail=f"Agent invocation failed: {retry_exc}"
                ) from retry_exc
        else:
            logger.exception("Agent invocation failed")
            raise HTTPException(status_code=502, detail=f"Agent invocation failed: {exc}") from exc

    return ChatResponse(response=raw_response, session_id=session_id, actor_id=actor_id)
