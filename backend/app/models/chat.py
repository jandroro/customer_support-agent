"""Request/response schemas for the /api/chat endpoint."""

from typing import Optional
from pydantic import BaseModel, Field


class ChatRequest(BaseModel):
    """Payload for `POST /api/chat`."""

    message: str = Field(min_length=1, description="The user's message to the agent.")
    session_id: Optional[str] = Field(
        default=None,
        description=(
            "AgentCore session id. Omit to start a new conversation — the "
            "response echoes back the id used, to reuse on subsequent turns."
        ),
    )
    actor_id: Optional[str] = Field(
        default=None,
        description=(
            "Identity used for AgentCore Memory personalization. Defaults to "
            "the logged-in user's username when access_token is set, "
            "otherwise to the shared service identity's default actor."
        ),
    )
    access_token: Optional[str] = Field(
        default=None,
        description=(
            "A logged-in user's own Cognito access token (from /api/auth/login "
            "or /api/auth/register). When provided, it's used to invoke the "
            "Runtime instead of the shared service identity."
        ),
    )


class ChatResponse(BaseModel):
    """Response for `POST /api/chat`."""

    response: str = Field(description="The agent's text response.")
    session_id: str = Field(
        description="The AgentCore session id used for this turn — reuse it to continue the conversation."
    )
    actor_id: str = Field(description="The actor_id used for AgentCore Memory on this turn.")
