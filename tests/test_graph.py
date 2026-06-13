import pytest
from langchain_core.messages import AIMessage, HumanMessage, ToolMessage

import claims_agent.graph as graph_module
from claims_agent.graph import build_graph


class DummyToolCallingModel:
    def bind_tools(self, tools):
        self.tools = tools
        return self

    def invoke(self, messages):
        last_message = messages[-1]
        if isinstance(last_message, HumanMessage):
            return AIMessage(
                content="",
                tool_calls=[
                    {
                        "id": "call-1",
                        "name": "lookup_claim_status",
                        "args": {"claim_id": "CLM-1001"},
                        "type": "tool_call",
                    }
                ],
            )
        if isinstance(last_message, ToolMessage):
            return AIMessage(content=f"Claim status response: {last_message.content}")
        raise AssertionError(f"Unexpected message type: {type(last_message)!r}")


def test_build_default_model_uses_default_azure_credential(monkeypatch) -> None:
    captured = {}

    class DummyCredential:
        pass

    class DummyAzureChatOpenAI:
        def __init__(self, **kwargs):
            captured["kwargs"] = kwargs

    monkeypatch.setenv("AZURE_OPENAI_ENDPOINT", "https://example.openai.azure.com/")
    monkeypatch.setenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4.1-mini")
    monkeypatch.setattr(graph_module, "DefaultAzureCredential", DummyCredential)
    monkeypatch.setattr(graph_module, "AzureChatOpenAI", DummyAzureChatOpenAI)
    monkeypatch.setattr(
        graph_module,
        "get_bearer_token_provider",
        lambda credential, scope: f"token::{scope}::{type(credential).__name__}",
    )

    model = graph_module._build_default_model()

    assert isinstance(model, DummyAzureChatOpenAI)
    assert captured["kwargs"] == {
        "azure_deployment": "gpt-4.1-mini",
        "azure_endpoint": "https://example.openai.azure.com",
        "azure_ad_token_provider": "token::https://ai.azure.com/.default::DummyCredential",
        "api_version": "2024-12-01-preview",
    }


def test_build_default_model_requires_azure_openai_configuration(monkeypatch) -> None:
    monkeypatch.delenv("AZURE_OPENAI_ENDPOINT", raising=False)
    monkeypatch.delenv("AZURE_OPENAI_DEPLOYMENT", raising=False)

    with pytest.raises(RuntimeError, match="AZURE_OPENAI_ENDPOINT and AZURE_OPENAI_DEPLOYMENT"):
        graph_module._build_default_model()


def test_build_graph_executes_tool_loop() -> None:
    graph = build_graph(model=DummyToolCallingModel())
    result = graph.invoke({"messages": [HumanMessage(content="What is the status of claim CLM-1001?")]})
    final_message = result["messages"][-1]
    assert isinstance(final_message, AIMessage)
    assert "CLM-1001" in final_message.content
    assert "approved" in final_message.content
