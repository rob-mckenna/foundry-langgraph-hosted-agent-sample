import importlib

import pytest
from fastapi.testclient import TestClient
from langchain_core.messages import AIMessage

standalone_app = importlib.import_module("standalone_api.app")


class RecordingGraph:
    def __init__(self) -> None:
        self.calls = []

    def invoke(self, payload, config):
        self.calls.append((payload, config))
        text = payload["messages"][0].content
        return {"messages": [AIMessage(content=f"Handled: {text}")]}


def test_build_chat_model_uses_default_azure_credential(monkeypatch) -> None:
    captured = {}

    class DummyCredential:
        pass

    class DummyChatOpenAI:
        def __init__(self, **kwargs):
            captured["kwargs"] = kwargs

    monkeypatch.setenv("AZURE_OPENAI_ENDPOINT", "https://example.openai.azure.com/")
    monkeypatch.setenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4.1-mini")
    monkeypatch.setattr(standalone_app, "DefaultAzureCredential", DummyCredential)
    monkeypatch.setattr(standalone_app, "ChatOpenAI", DummyChatOpenAI)
    monkeypatch.setattr(
        standalone_app,
        "get_bearer_token_provider",
        lambda credential, scope: f"token::{scope}::{type(credential).__name__}",
    )

    model = standalone_app.build_chat_model()

    assert isinstance(model, DummyChatOpenAI)
    assert captured["kwargs"] == {
        "model": "gpt-4.1-mini",
        "base_url": "https://example.openai.azure.com/openai/deployments/gpt-4.1-mini",
        "api_key": "token::https://cognitiveservices.azure.com/.default::DummyCredential",
    }


def test_build_chat_model_requires_azure_openai_configuration(monkeypatch) -> None:
    monkeypatch.delenv("AZURE_OPENAI_ENDPOINT", raising=False)
    monkeypatch.delenv("AZURE_OPENAI_DEPLOYMENT", raising=False)

    with pytest.raises(RuntimeError, match="AZURE_OPENAI_ENDPOINT and AZURE_OPENAI_DEPLOYMENT"):
        standalone_app.build_chat_model()


def test_chat_endpoint_uses_thread_id_and_returns_last_ai_message(monkeypatch) -> None:
    graph = RecordingGraph()
    monkeypatch.setattr(standalone_app, "get_graph", lambda: graph)
    client = TestClient(standalone_app.app)

    response = client.post(
        "/chat",
        json={"message": "Check claim CLM-1001", "thread_id": "thread-123"},
    )

    assert response.status_code == 200
    assert response.json() == {
        "thread_id": "thread-123",
        "response": "Handled: Check claim CLM-1001",
    }
    assert graph.calls[0][1]["configurable"]["thread_id"] == "thread-123"
