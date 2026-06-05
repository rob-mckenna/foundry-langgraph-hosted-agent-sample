import os
from typing import Any

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from langchain_core.messages import AIMessage, SystemMessage
from langchain_openai import ChatOpenAI
from langgraph.graph import END, START, StateGraph
from langgraph.prebuilt import ToolNode

from claims_agent.prompts import CLAIMS_ASSISTANT_SYSTEM_PROMPT
from claims_agent.state import ClaimsAgentState
from claims_agent.tools import CLAIMS_TOOLS


def _build_default_model() -> ChatOpenAI:
    azure_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT", "").strip().rstrip("/")
    azure_deployment = os.getenv("AZURE_OPENAI_DEPLOYMENT", "").strip()
    if not azure_endpoint or not azure_deployment:
        raise RuntimeError(
            "Azure OpenAI configuration is required. Set AZURE_OPENAI_ENDPOINT and AZURE_OPENAI_DEPLOYMENT, then run az login before starting the agent."
        )

    credential = DefaultAzureCredential()
    token_provider = get_bearer_token_provider(
        credential,
        "https://cognitiveservices.azure.com/.default",
    )
    return ChatOpenAI(
        model=azure_deployment,
        base_url=f"{azure_endpoint}/openai/deployments/{azure_deployment}",
        api_key=token_provider,
    )


def build_graph(model: ChatOpenAI | Any | None = None, checkpointer: Any | None = None):
    configured_model = (model or _build_default_model()).bind_tools(CLAIMS_TOOLS)
    tool_node = ToolNode(CLAIMS_TOOLS)

    def call_model(state: ClaimsAgentState) -> dict:
        response = configured_model.invoke(
            [SystemMessage(content=CLAIMS_ASSISTANT_SYSTEM_PROMPT), *state["messages"]]
        )
        return {"messages": [response]}

    def route_after_agent(state: ClaimsAgentState) -> str:
        last_message = state["messages"][-1]
        if isinstance(last_message, AIMessage) and last_message.tool_calls:
            return "tools"
        return "__end__"

    builder = StateGraph(ClaimsAgentState)
    builder.add_node("agent", call_model)
    builder.add_node("tools", tool_node)
    builder.add_edge(START, "agent")
    builder.add_conditional_edges(
        "agent",
        route_after_agent,
        {"tools": "tools", "__end__": END},
    )
    builder.add_edge("tools", "agent")
    return builder.compile(checkpointer=checkpointer)
