"""Request/response schemas for the /api/auth/* endpoints."""

from typing import Optional
from pydantic import BaseModel, Field


class RegisterRequest(BaseModel):
    """Payload for `POST /api/auth/register`."""

    username: str = Field(min_length=3, max_length=128, description="Desired Cognito username.")
    password: str = Field(min_length=8, description="Password (MCPServerPool policy: 8+ characters).")
    email: Optional[str] = Field(
        default=None,
        description="Optional email, stored as a user attribute (not verified — this pool has no email/SMS sender configured).",
    )


class LoginRequest(BaseModel):
    """Payload for `POST /api/auth/login`."""

    username: str = Field(description="Cognito username.")
    password: str = Field(description="Cognito password.")


class RefreshRequest(BaseModel):
    """Payload for `POST /api/auth/refresh`."""

    username: str = Field(description="Cognito username.")
    refresh_token: str = Field(description="Refresh token previously returned by login/register/refresh.")


class AuthResponse(BaseModel):
    """Token bundle shared by `/api/auth/register`, `/api/auth/login`, and `/api/auth/refresh`."""

    access_token: str = Field(description="Short-lived JWT (60 min) — pass this as ChatRequest.access_token.")
    id_token: str = Field(description="Cognito ID token, carries user identity claims.")
    refresh_token: str = Field(description="Long-lived token — exchange it via /api/auth/refresh for a new access_token.")
    username: str = Field(description="The authenticated user's username.")
