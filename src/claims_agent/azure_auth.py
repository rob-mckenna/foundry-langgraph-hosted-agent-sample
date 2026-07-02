import os

from azure.identity import DefaultAzureCredential


def build_credential() -> DefaultAzureCredential:
    use_managed_identity = os.getenv("USE_MANAGED_IDENTITY", "false").strip().lower() == "true"
    return DefaultAzureCredential(
        exclude_managed_identity_credential=not use_managed_identity,
    )
