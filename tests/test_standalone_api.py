import importlib

import pytest
from fastapi.testclient import TestClient
from langchain_core.messages import AIMessage, HumanMessage, ToolMessage

standalone_app = importlib.import_module("standalone_api.app")


class RecordingGraph:
    def __init__(self) -> None:
        self.calls = []

    def invoke(self, payload, config):
        self.calls.append((payload, config))
        text = payload["messages"][0].content
        return {"messages": [AIMessage(content=f"Handled: {text}")]}


class HistoryGraph:
    def get_state(self, config):
        assert config == {"configurable": {"thread_id": "thread-123"}}
        return type(
            "StateSnapshot",
            (),
            {
                "values": {
                    "messages": [
                        HumanMessage(content="Check claim CLM-1001"),
                        AIMessage(content="I can help with that."),
                        AIMessage(content="", tool_calls=[{"id": "call-1", "name": "lookup_claim_status", "args": {}, "type": "tool_call"}]),
                        ToolMessage(content='{"claim_id":"CLM-1001","status":"approved"}', tool_call_id="call-1"),
                        AIMessage(content="Claim CLM-1001 is approved."),
                    ]
                }
            },
        )()


class EmptyHistoryGraph:
    def get_state(self, config):
        return type("StateSnapshot", (), {"values": {}})()


def test_build_chat_model_uses_default_azure_credential(monkeypatch) -> None:
    captured = {}

    class DummyCredential:
        pass

    class DummyAzureChatOpenAI:
        def __init__(self, **kwargs):
            captured["kwargs"] = kwargs

    monkeypatch.setenv("AZURE_OPENAI_ENDPOINT", "https://example.openai.azure.com/")
    monkeypatch.setenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4.1-mini")
    monkeypatch.setattr(standalone_app, "DefaultAzureCredential", DummyCredential)
    monkeypatch.setattr(standalone_app, "AzureChatOpenAI", DummyAzureChatOpenAI)
    monkeypatch.setattr(
        standalone_app,
        "get_bearer_token_provider",
        lambda credential, scope: f"token::{scope}::{type(credential).__name__}",
    )

    model = standalone_app.build_chat_model()

    assert isinstance(model, DummyAzureChatOpenAI)
    assert captured["kwargs"] == {
        "azure_deployment": "gpt-4.1-mini",
        "azure_endpoint": "https://example.openai.azure.com",
        "azure_ad_token_provider": "token::https://ai.azure.com/.default::DummyCredential",
        "api_version": "2024-12-01-preview",
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


def test_chat_history_returns_user_and_assistant_messages_only(monkeypatch) -> None:
    monkeypatch.setattr(standalone_app, "get_graph", lambda: HistoryGraph())
    client = TestClient(standalone_app.app)

    response = client.get("/chat/history", params={"thread_id": "thread-123"})

    assert response.status_code == 200
    assert response.json() == {
        "thread_id": "thread-123",
        "messages": [
            {"role": "user", "content": "Check claim CLM-1001"},
            {"role": "assistant", "content": "I can help with that."},
            {"role": "assistant", "content": "Claim CLM-1001 is approved."},
        ],
    }


def test_chat_history_returns_empty_list_for_unknown_thread(monkeypatch) -> None:
    monkeypatch.setattr(standalone_app, "get_graph", lambda: EmptyHistoryGraph())
    client = TestClient(standalone_app.app)

    response = client.get("/chat/history", params={"thread_id": "thread-999"})

    assert response.status_code == 200
    assert response.json() == {"thread_id": "thread-999", "messages": []}
