import importlib

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
