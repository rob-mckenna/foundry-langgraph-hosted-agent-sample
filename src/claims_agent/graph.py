import os
from typing import Any

from langchain_core.messages import AIMessage, SystemMessage
from langchain_openai import ChatOpenAI
from langgraph.graph import END, START, StateGraph
from langgraph.prebuilt import ToolNode

from claims_agent.prompts import CLAIMS_ASSISTANT_SYSTEM_PROMPT
from claims_agent.state import ClaimsAgentState
from claims_agent.tools import CLAIMS_TOOLS


def _build_default_model() -> ChatOpenAI:
    azure_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT", "").strip()
    azure_api_key = os.getenv("AZURE_OPENAI_API_KEY", "").strip()
    azure_deployment = os.getenv("AZURE_OPENAI_DEPLOYMENT", "").strip()
    if azure_endpoint and azure_api_key and azure_deployment:
        return ChatOpenAI(
            model=azure_deployment,
            api_key=azure_api_key,
            base_url=f"{azure_endpoint.rstrip('/')}/openai/v1/",
        )

    openai_api_key = os.getenv("OPENAI_API_KEY", "").strip()
    if openai_api_key:
        return ChatOpenAI(
            model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
            api_key=openai_api_key,
        )

    raise RuntimeError(
        "No chat model configuration was found. Set OPENAI_API_KEY or the Azure OpenAI environment variables."
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
