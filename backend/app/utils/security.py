"""Generic security helpers with no AWS SDK calls of their own."""

import base64
import hashlib
import hmac


def compute_cognito_secret_hash(username: str, client_id: str, client_secret: str) -> str:
    """Compute the Cognito SECRET_HASH auth parameter.

    Cognito requires this HMAC-SHA256 value on every auth call made against
    an app client that has a client secret enabled (see AWS docs:
    "Computing secret hash values").

    Args:
        username: The Cognito username being authenticated.
        client_id: The app client ID.
        client_secret: The app client secret.

    Returns:
        The base64-encoded SECRET_HASH value.
    """
    message = bytes(username + client_id, "utf-8")
    key = bytes(client_secret, "utf-8")
    digest = hmac.new(key, message, digestmod=hashlib.sha256).digest()
    return base64.b64encode(digest).decode()
