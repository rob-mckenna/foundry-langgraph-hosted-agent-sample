from __future__ import annotations

import inspect
import json
import sys
from pathlib import Path
from typing import Any
from unittest.mock import Mock

import pytest

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"

if SRC.exists():
    sys.path.insert(0, str(SRC))


def extract_text(value: Any) -> str:
    """Best-effort text extraction for graph outputs, tool results, and API payloads."""
    if value is None:
        return ""

    if isinstance(value, str):
        return value

    if isinstance(value, dict):
        for key in ("output_text", "response", "content", "text", "answer", "result", "message"):
            if key in value:
                return extract_text(value[key])
        if "messages" in value and value["messages"]:
            return extract_text(value["messages"][-1])
        return json.dumps(value, default=str)

    if isinstance(value, (list, tuple)):
        if not value:
            return ""
        return extract_text(value[-1])

    content = getattr(value, "content", None)
    if content is not None:
        return extract_text(content)

    if hasattr(value, "model_dump"):
        return json.dumps(value.model_dump(), default=str)

    if hasattr(value, "dict"):
        return json.dumps(value.dict(), default=str)

    return str(value)


class MockLLM:
    def __init__(self) -> None:
        self.calls: list[dict[str, Any]] = []
        self.bound_tools: list[Any] = []

    def bind_tools(self, tools: list[Any], **_: Any) -> "MockLLM":
        self.bound_tools = list(tools)
        return self

    def invoke(self, input: Any, config: Any = None, **kwargs: Any) -> Any:
        self.calls.append({"input": input, "config": config, "kwargs": kwargs})
        prompt = extract_text(input).lower()

        if "claim" in prompt:
            content = "Use check_claim_status for claim CLM1001."
        elif "eligib" in prompt or "member" in prompt:
            content = "Use check_eligibility for member MEM1001."
        elif "benefit" in prompt or "plan" in prompt:
            content = "Use get_benefit_summary for plan PLAN100."
        else:
            content = "I can help with claim status, eligibility, or benefit summary questions."

        try:
            from langchain_core.messages import AIMessage

            return AIMessage(content=content)
        except Exception:
            return {"role": "assistant", "content": content}

    async def ainvoke(self, input: Any, config: Any = None, **kwargs: Any) -> Any:
        return self.invoke(input, config=config, **kwargs)


@pytest.fixture()
def mock_llm() -> MockLLM:
    return MockLLM()


@pytest.fixture()
def environment_variables(monkeypatch: pytest.MonkeyPatch) -> dict[str, str]:
    env = {
        "OPENAI_API_KEY": "test-openai-key",
        "OPENAI_MODEL": "gpt-4o-mini",
        "AZURE_OPENAI_API_KEY": "test-azure-openai-key",
        "AZURE_OPENAI_ENDPOINT": "https://example.openai.azure.com/",
        "AZURE_OPENAI_CHAT_DEPLOYMENT_NAME": "gpt-4o-mini",
        "AZURE_OPENAI_API_VERSION": "2024-10-21",
        "FOUNDRY_PROJECT_ENDPOINT": "https://example.services.ai.azure.com/api/projects/test-project",
        "FOUNDRY_MODEL_DEPLOYMENT_NAME": "gpt-4o-mini",
    }

    for key, value in env.items():
        monkeypatch.setenv(key, value)

    return env


@pytest.fixture()
def compiled_graph(mock_llm: MockLLM, monkeypatch: pytest.MonkeyPatch, environment_variables: dict[str, str]) -> Any:
    graph_module = pytest.importorskip("claims_agent.graph")

    for attr_name in (
        "build_model",
        "get_model",
        "create_model",
        "build_llm",
        "get_llm",
    ):
        if hasattr(graph_module, attr_name):
            monkeypatch.setattr(graph_module, attr_name, Mock(return_value=mock_llm))

    for attr_name in (
        "ChatOpenAI",
        "AzureChatOpenAI",
        "AzureAIChatCompletionsModel",
    ):
        if hasattr(graph_module, attr_name):
            monkeypatch.setattr(graph_module, attr_name, Mock(return_value=mock_llm))

    build_graph = getattr(graph_module, "build_graph", None)
    if build_graph is None:
        pytest.skip("claims_agent.graph.build_graph is not implemented yet")

    signature = inspect.signature(build_graph)
    kwargs: dict[str, Any] = {}

    for parameter_name in signature.parameters:
        if parameter_name in {"llm", "model", "chat_model"}:
            kwargs[parameter_name] = mock_llm

    graph = build_graph(**kwargs)
    if hasattr(graph, "compile") and callable(graph.compile):
        graph = graph.compile()

    return graph
