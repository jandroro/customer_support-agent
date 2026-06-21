from .aws_clients import ssm_client


# =====================================================
# PARAMETER STORE
# =====================================================

def get_ssm_parameter(name: str, with_decryption: bool = True) -> str:
    response = ssm_client.get_parameter(Name=name, WithDecryption=with_decryption)
    return response["Parameter"]["Value"]