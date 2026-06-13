import foundry_host.app as foundry_app


def test_build_foundry_model_uses_azure_endpoint_and_token_provider(monkeypatch) -> None:
    captured = {}

    class DummyCredential:
        pass

    class DummyAzureChatOpenAI:
        def __init__(self, **kwargs):
            captured["kwargs"] = kwargs

    monkeypatch.setenv("FOUNDRY_PROJECT_ENDPOINT", "https://project.example.test/")
    monkeypatch.setenv("AZURE_AI_MODEL_DEPLOYMENT_NAME", "gpt-4.1-mini")
    monkeypatch.setattr(foundry_app, "DefaultAzureCredential", DummyCredential)
    monkeypatch.setattr(foundry_app, "AzureChatOpenAI", DummyAzureChatOpenAI)
    monkeypatch.setattr(foundry_app, "get_bearer_token_provider", lambda credential, scope: lambda: f"token::{scope}")

    model = foundry_app.build_foundry_model()

    assert isinstance(model, DummyAzureChatOpenAI)
    assert captured["kwargs"]["azure_endpoint"] == "https://project.example.test"
    assert captured["kwargs"]["azure_deployment"] == "gpt-4.1-mini"
    assert captured["kwargs"]["api_version"] == "2024-10-21"
    # token_provider is a callable, check it's passed
    assert callable(captured["kwargs"]["azure_ad_token_provider"])


def test_main_wraps_graph_in_responses_host_server(monkeypatch) -> None:
    captured = {}
    sentinel_model = object()
    sentinel_graph = object()

    class DummyServer:
        def __init__(self, agent):
            captured["agent"] = agent

        def run(self, port):
            captured["port"] = port

    monkeypatch.setattr(foundry_app, "build_foundry_model", lambda: sentinel_model)
    monkeypatch.setattr(foundry_app, "build_graph", lambda model=None, checkpointer=None: sentinel_graph if model is sentinel_model else None)
    monkeypatch.setattr(foundry_app, "ResponsesHostServer", DummyServer)
    monkeypatch.setenv("PORT", "9091")

    foundry_app.main()

    assert isinstance(captured["agent"], foundry_app.LangGraphHostedAgent)
    assert captured["port"] == 9091
