"""Shared boto3/SSM helpers, used by every service that talks to AWS."""

import boto3

from ..core.config import settings


def get_boto_session() -> boto3.Session:
    """Build a boto3 session from the app's configured AWS profile/region.

    Returns:
        A new `boto3.Session` using `settings.aws.profile` (or the attached
        IAM role, when `profile` is `None`) and `settings.aws.region`.
    """
    return boto3.Session(profile_name=settings.aws.profile, region_name=settings.aws.region)


def get_ssm_parameter(name: str, with_decryption: bool = True) -> str:
    """Fetch a single SSM parameter value.

    Args:
        name: Fully-qualified SSM parameter name.
        with_decryption: Whether to decrypt SecureString parameters.

    Returns:
        The parameter's string value.

    Raises:
        botocore.exceptions.ClientError: If the parameter doesn't exist or
            the caller lacks `ssm:GetParameter` permission.
    """
    ssm = get_boto_session().client("ssm")
    response = ssm.get_parameter(Name=name, WithDecryption=with_decryption)
    return response["Parameter"]["Value"]
