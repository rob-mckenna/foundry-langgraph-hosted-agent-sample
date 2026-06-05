import os
import uuid
from typing import Any, Mapping

from agent_framework import AgentResponse, AgentSession, Message
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from dotenv import load_dotenv
from langchain_core.messages import AIMessage, HumanMessage
from langchain_openai import AzureChatOpenAI
from langgraph.checkpoint.memory import MemorySaver

try:
    from langchain_azure_ai.agents.hosting import ResponsesHostServer
except ImportError:  # pragma: no cover - compatibility fallback for current package layout.
    from agent_framework_foundry_hosting import ResponsesHostServer

from claims_agent.graph import build_graph

load_dotenv()


class LangGraphHostedAgent:
    """Adapter wrapping a compiled LangGraph graph for Foundry's SupportsAgentRun protocol."""

    def __init__(self, graph: Any) -> None:
        self._graph = graph
        self.id = "claims-status-inquiry-agent"
        self.name = "Claims Status Inquiry Agent"
        self.description = "A claims processing assistant for health insurance payors."

    async def run(
        self,
        messages: Any = None,
        *,
        stream: bool = False,
        session: "AgentSession | None" = None,
        function_invocation_kwargs: "Mapping[str, Any] | None" = None,
        client_kwargs: "Mapping[str, Any] | None" = None,
        **kwargs: Any,
    ) -> AgentResponse:
        user_text = ""
        if isinstance(messages, str):
            user_text = messages
        elif isinstance(messages, list):
            for m in messages:
                if hasattr(m, "contents") and m.contents:
                    for c in m.contents:
                        if isinstance(c, str):
                            user_text = c
                        elif hasattr(c, "text"):
                            user_text = c.text
        elif hasattr(messages, "contents"):
            for c in messages.contents:
                if isinstance(c, str):
                    user_text = c
                elif hasattr(c, "text"):
                    user_text = c.text

        thread_id = session.service_session_id if session and session.service_session_id else str(uuid.uuid4())
        result = self._graph.invoke(
            {"messages": [HumanMessage(content=user_text)]},
            config={"configurable": {"thread_id": thread_id}},
        )

        response_text = ""
        for msg in reversed(result["messages"]):
            if isinstance(msg, AIMessage) and msg.content:
                response_text = msg.content if isinstance(msg.content, str) else str(msg.content)
                break

        return AgentResponse(
            messages=[Message("assistant", [response_text])],
            response_id=f"resp_{uuid.uuid4().hex[:16]}",
        )

    def create_session(self, *, session_id: str | None = None) -> AgentSession:
        return AgentSession(session_id=session_id)

    def get_session(self, service_session_id: str, *, session_id: str | None = None) -> AgentSession:
        return AgentSession(service_session_id=service_session_id, session_id=session_id)


def build_foundry_model() -> AzureChatOpenAI:
    endpoint = os.environ["FOUNDRY_PROJECT_ENDPOINT"].rstrip("/")
    deployment = os.environ.get("AZURE_AI_MODEL_DEPLOYMENT_NAME", "gpt-4.1")
    api_version = os.environ.get("AZURE_AI_API_VERSION", "2024-12-01-preview")
    credential = DefaultAzureCredential()
    token_provider = get_bearer_token_provider(credential, "https://cognitiveservices.azure.com/.default")
    return AzureChatOpenAI(
        azure_endpoint=endpoint,
        azure_deployment=deployment,
        api_version=api_version,
        azure_ad_token_provider=token_provider,
    )


def main() -> None:
    model = build_foundry_model()
    checkpointer = MemorySaver()
    graph = build_graph(model=model, checkpointer=checkpointer)
    agent = LangGraphHostedAgent(graph)
    port = int(os.environ.get("PORT", "8088"))
    ResponsesHostServer(agent).run(port=port)


if __name__ == "__main__":
    main()
