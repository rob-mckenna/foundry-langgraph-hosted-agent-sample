import claims_agent.azure_auth as azure_auth


def test_build_credential_excludes_managed_identity_by_default(monkeypatch) -> None:
    captured = {}

    class DummyCredential:
        def __init__(self, **kwargs):
            captured["kwargs"] = kwargs

    monkeypatch.delenv("USE_MANAGED_IDENTITY", raising=False)
    monkeypatch.setattr(azure_auth, "DefaultAzureCredential", DummyCredential)

    credential = azure_auth.build_credential()

    assert isinstance(credential, DummyCredential)
    assert captured["kwargs"] == {"exclude_managed_identity_credential": True}


def test_build_credential_uses_managed_identity_when_enabled(monkeypatch) -> None:
    captured = {}

    class DummyCredential:
        def __init__(self, **kwargs):
            captured["kwargs"] = kwargs

    monkeypatch.setenv("USE_MANAGED_IDENTITY", "true")
    monkeypatch.setattr(azure_auth, "DefaultAzureCredential", DummyCredential)

    credential = azure_auth.build_credential()

    assert isinstance(credential, DummyCredential)
    assert captured["kwargs"] == {"exclude_managed_identity_credential": False}
