"""User registration, login, and token refresh against MCPServerPool."""

from fastapi import APIRouter, HTTPException
from ...models.auth import AuthResponse, LoginRequest, RefreshRequest, RegisterRequest
from ...services import cognito_auth


router = APIRouter(prefix="/api/auth", tags=["Auth"])


@router.post(
    "/register",
    response_model=AuthResponse,
    summary="Register a new user",
    responses={400: {"description": "Username already taken or invalid input"}},
)
def register(request: RegisterRequest) -> AuthResponse:
    """Create a new MCPServerPool user and log them in.

    Uses `cognito_auth.register_user` (admin-created, auto-confirmed — no
    email verification step), then immediately authenticates the new account
    so the caller gets a usable token bundle in one round trip.

    Args:
        request: Desired username, password, and optional email.

    Returns:
        A fresh token bundle for the newly created user.

    Raises:
        HTTPException: 400 if the username is already taken.
    """
    try:
        cognito_auth.register_user(request.username, request.password, request.email)
        tokens = cognito_auth.authenticate_user(request.username, request.password)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return AuthResponse(**tokens)


@router.post(
    "/login",
    response_model=AuthResponse,
    summary="Authenticate an existing user",
    responses={401: {"description": "Invalid username or password"}},
)
def login(request: LoginRequest) -> AuthResponse:
    """Authenticate an existing MCPServerPool user.

    Args:
        request: Username and password to verify.

    Returns:
        The user's own JWTs, to be used as `ChatRequest.access_token`.

    Raises:
        HTTPException: 401 if the credentials are invalid.
    """
    try:
        tokens = cognito_auth.authenticate_user(request.username, request.password)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    return AuthResponse(**tokens)


@router.post(
    "/refresh",
    response_model=AuthResponse,
    summary="Refresh an access token",
    responses={401: {"description": "Refresh token expired or invalid — the user must log in again"}},
)
def refresh(request: RefreshRequest) -> AuthResponse:
    """Exchange a refresh token for a new access token.

    Lets the frontend keep a session alive without re-prompting for a
    password every time the short-lived access token expires.

    Args:
        request: Username and the refresh token previously issued for it.

    Returns:
        A fresh token bundle.

    Raises:
        HTTPException: 401 if the refresh token is expired or invalid.
    """
    try:
        tokens = cognito_auth.refresh_user_token(request.username, request.refresh_token)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    return AuthResponse(**tokens)
