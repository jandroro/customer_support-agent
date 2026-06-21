"""Two Cognito identities are at play in this module, both against the same
MCPServerPool (the only pool the Runtime/Gateway CUSTOM_JWT authorizer trusts):

1. A shared service identity (testuser) — get_bearer_token() — mirroring
   lab_helpers.utils.get_or_create_cognito_pool() from the project's
   notebooks. Used as a fallback when a request has no logged-in user.
2. Real per-user accounts — register_user() / authenticate_user() /
   refresh_user_token() — backing the frontend's login/register screens, so
   each human user gets their own JWT (and AgentCore Memory actor_id).
"""

import time
from dataclasses import dataclass
from typing import Optional

from pycognito import Cognito

from ..core.config import settings
from ..utils.aws import get_boto_session, get_ssm_parameter
from ..utils.security import compute_cognito_secret_hash

_REFRESH_MARGIN_SECONDS = 300  # refresh 5 minutes before the token actually expires


@dataclass
class _TokenCache:
    """In-memory cache for the shared service identity's bearer token.

    Attributes:
        bearer_token: The last issued access token, or `None` if never fetched.
        expires_at: Unix timestamp after which the cached token should be
            treated as stale and refreshed (already adjusted by
            `_REFRESH_MARGIN_SECONDS`).
    """

    bearer_token: Optional[str] = None
    expires_at: float = 0.0


_cache = _TokenCache()


def _get_pool_id() -> str:
    """Fetch the MCPServerPool user pool ID from SSM."""
    return get_ssm_parameter(settings.cognito.pool_id_ssm_parameter, with_decryption=False)


def _get_client_id() -> str:
    """Fetch the MCPServerPoolClient app client ID from SSM."""
    return get_ssm_parameter(settings.cognito.client_id_ssm_parameter, with_decryption=False)


def _get_client_secret() -> str:
    """Fetch the MCPServerPoolClient app client secret from SSM (SecureString)."""
    return get_ssm_parameter(settings.cognito.client_secret_ssm_parameter)


def register_user(username: str, password: str, email: Optional[str] = None) -> None:
    """Create a new user in MCPServerPool.

    Uses admin_create_user (instant, auto-confirmed) rather than the public
    self-service sign_up API, which would require email/SMS verification —
    not configured for this lab pool. Mirrors the admin_create_user +
    admin_set_user_password pattern already used for `testuser` in
    lab_helpers.utils.get_or_create_cognito_pool().

    Args:
        username: Desired username, unique within MCPServerPool.
        password: Password to set as permanent (skips the
            force-change-password flow `admin_create_user` would otherwise
            trigger).
        email: Optional email, stored as a user attribute. Not verified —
            this pool has no email/SMS sender configured.

    Raises:
        ValueError: If `username` is already taken.
    """
    pool_id = _get_pool_id()
    cognito_client = get_boto_session().client("cognito-idp")

    user_attributes = [{"Name": "email", "Value": email}] if email else []

    try:
        cognito_client.admin_create_user(
            UserPoolId=pool_id,
            Username=username,
            TemporaryPassword=password,
            MessageAction="SUPPRESS",
            UserAttributes=user_attributes,
        )
    except cognito_client.exceptions.UsernameExistsException as exc:
        raise ValueError(f"Username '{username}' is already taken") from exc

    cognito_client.admin_set_user_password(
        UserPoolId=pool_id,
        Username=username,
        Password=password,
        Permanent=True,
    )


def authenticate_user(username: str, password: str) -> dict:
    """Authenticate a real user via SRP and return their own tokens.

    Independent of the shared service-identity cache used by
    `get_bearer_token` — every call re-authenticates against Cognito.

    Args:
        username: The Cognito username to authenticate.
        password: The user's password.

    Returns:
        A dict with `access_token`, `id_token`, `refresh_token`, and `username`.

    Raises:
        ValueError: If the username/password combination is invalid.
    """
    user = Cognito(
        user_pool_id=_get_pool_id(),
        client_id=_get_client_id(),
        client_secret=_get_client_secret(),
        username=username,
        user_pool_region=settings.aws.region,
        session=get_boto_session(),
    )
    try:
        user.authenticate(password=password)
    except Exception as exc:
        raise ValueError("Invalid username or password") from exc

    return {
        "access_token": user.access_token,
        "id_token": user.id_token,
        "refresh_token": user.refresh_token,
        "username": username,
    }


def refresh_user_token(username: str, refresh_token: str) -> dict:
    """Exchange a refresh token for a fresh access token.

    Args:
        username: The Cognito username the refresh token was issued for.
        refresh_token: A refresh token previously returned by
            `authenticate_user` or a prior call to this function.

    Returns:
        A dict with `access_token`, `id_token`, `refresh_token`, and `username`.

    Raises:
        ValueError: If the refresh token is expired or invalid — the caller
            must re-authenticate with `authenticate_user` instead.
    """
    user = Cognito(
        user_pool_id=_get_pool_id(),
        client_id=_get_client_id(),
        client_secret=_get_client_secret(),
        username=username,
        user_pool_region=settings.aws.region,
        refresh_token=refresh_token,
        session=get_boto_session(),
    )
    try:
        user.renew_access_token()
    except Exception as exc:
        raise ValueError("Session expired — please log in again") from exc

    return {
        "access_token": user.access_token,
        "id_token": user.id_token,
        "refresh_token": user.refresh_token or refresh_token,
        "username": username,
    }


def get_bearer_token(force_refresh: bool = False) -> str:
    """Return a cached bearer token for the shared service identity.

    Authenticates (or re-authenticates) against Cognito only when the cache
    is empty or near expiry, to avoid an extra round trip on every chat request.

    Args:
        force_refresh: If `True`, bypass the cache and re-authenticate even
            if the cached token hasn't expired yet — used after a 401/403
            from the Runtime to recover from a stale token.

    Returns:
        A valid MCPServerPool access token for the `testuser` service identity.
    """
    if not force_refresh and _cache.bearer_token and time.time() < _cache.expires_at:
        return _cache.bearer_token

    client_id = _get_client_id()
    client_secret = _get_client_secret()
    username = settings.cognito.test_username
    secret_hash = compute_cognito_secret_hash(username, client_id, client_secret)

    cognito_client = get_boto_session().client("cognito-idp")
    auth_response = cognito_client.initiate_auth(
        ClientId=client_id,
        AuthFlow="USER_PASSWORD_AUTH",
        AuthParameters={
            "USERNAME": username,
            "PASSWORD": settings.cognito.test_password,
            "SECRET_HASH": secret_hash,
        },
    )
    result = auth_response["AuthenticationResult"]
    _cache.bearer_token = result["AccessToken"]
    _cache.expires_at = time.time() + result["ExpiresIn"] - _REFRESH_MARGIN_SECONDS
    return _cache.bearer_token
