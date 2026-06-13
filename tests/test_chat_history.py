import importlib

from fastapi.testclient import TestClient
from langchain_core.messages import AIMessage, HumanMessage
from langgraph.checkpoint.memory import MemorySaver

from claims_agent.graph import build_graph

standalone_app = importlib.import_module("standalone_api.app")


class EchoHistoryModel:
    def bind_tools(self, tools):
        self.tools = tools
        return self

    def invoke(self, messages):
        human_messages = [message.content for message in messages if isinstance(message, HumanMessage)]
        return AIMessage(content=f"Handled: {human_messages[-1]}")



def test_chat_history_endpoint_returns_conversation_messages(monkeypatch) -> None:
    graph = build_graph(model=EchoHistoryModel(), checkpointer=MemorySaver())
    monkeypatch.setattr(standalone_app, "get_graph", lambda: graph)
    client = TestClient(standalone_app.app)

    client.post("/chat", json={"message": "First question", "thread_id": "thread-123"})
    client.post("/chat", json={"message": "Second question", "thread_id": "thread-123"})
    response = client.get("/chat/history", params={"thread_id": "thread-123"})

    assert response.status_code == 200
    assert response.json() == {
        "thread_id": "thread-123",
        "messages": [
            {"role": "user", "content": "First question"},
            {"role": "assistant", "content": "Handled: First question"},
            {"role": "user", "content": "Second question"},
            {"role": "assistant", "content": "Handled: Second question"},
        ],
    }



def test_chat_history_endpoint_returns_empty_messages_for_new_thread(monkeypatch) -> None:
    graph = build_graph(model=EchoHistoryModel(), checkpointer=MemorySaver())
    monkeypatch.setattr(standalone_app, "get_graph", lambda: graph)
    client = TestClient(standalone_app.app)

    response = client.get("/chat/history", params={"thread_id": "brand-new-thread"})

    assert response.status_code == 200
    assert response.json() == {"thread_id": "brand-new-thread", "messages": []}
