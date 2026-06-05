from types import SimpleNamespace

import foundry_host.app as foundry_app


def test_build_foundry_model_uses_project_endpoint_and_token_provider(monkeypatch) -> None:
    captured = {}

    class DummyCredential:
        pass

    class DummyProjectClient:
        def __init__(self, endpoint, credential):
            captured["endpoint"] = endpoint
            captured["credential"] = credential

        def get_openai_client(self):
            return SimpleNamespace(base_url="https://example.test/openai/v1/")

    class DummyChatOpenAI:
        def __init__(self, **kwargs):
            captured["kwargs"] = kwargs

    monkeypatch.setenv("FOUNDRY_PROJECT_ENDPOINT", "https://project.example.test/")
    monkeypatch.setenv("AZURE_AI_MODEL_DEPLOYMENT_NAME", "gpt-4.1-mini")
    monkeypatch.setattr(foundry_app, "DefaultAzureCredential", DummyCredential)
    monkeypatch.setattr(foundry_app, "AIProjectClient", DummyProjectClient)
    monkeypatch.setattr(foundry_app, "ChatOpenAI", DummyChatOpenAI)
    monkeypatch.setattr(foundry_app, "get_bearer_token_provider", lambda credential, scope: f"token::{scope}")

    model = foundry_app.build_foundry_model()

    assert isinstance(model, DummyChatOpenAI)
    assert captured["endpoint"] == "https://project.example.test"
    assert captured["kwargs"]["model"] == "gpt-4.1-mini"
    assert captured["kwargs"]["api_key"] == "token::https://ai.azure.com/.default"


def test_main_wraps_graph_in_responses_host_server(monkeypatch) -> None:
    captured = {}
    sentinel_model = object()
    sentinel_graph = object()

    class DummyServer:
        def __init__(self, graph):
            captured["graph"] = graph

        def run(self, port):
            captured["port"] = port

    monkeypatch.setattr(foundry_app, "build_foundry_model", lambda: sentinel_model)
    monkeypatch.setattr(foundry_app, "build_graph", lambda model=None: sentinel_graph if model is sentinel_model else None)
    monkeypatch.setattr(foundry_app, "ResponsesHostServer", DummyServer)
    monkeypatch.setenv("PORT", "9091")

    foundry_app.main()

    assert captured == {"graph": sentinel_graph, "port": 9091}
