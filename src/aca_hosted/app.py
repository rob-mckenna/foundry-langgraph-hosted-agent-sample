import os
import uuid
from typing import Any, Mapping

from agent_framework import AgentResponse, AgentSession, Message
from azure.identity import get_bearer_token_provider
from dotenv import load_dotenv
from langchain_core.messages import AIMessage, HumanMessage
from langchain_openai import AzureChatOpenAI
from langgraph.checkpoint.memory import MemorySaver

try:
    from langchain_azure_ai.agents.hosting import ResponsesHostServer
except ImportError:  # pragma: no cover - compatibility fallback for current package layout.
    from agent_framework_foundry_hosting import ResponsesHostServer

from claims_agent.azure_auth import build_credential
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
    # Determine the correct endpoint for model calls.
    # In Foundry Hosted Agent mode, the agent identity only has Foundry User role,
    # which grants model access through the project-scoped path. The runtime sets
    # FOUNDRY_PROJECT_ENDPOINT to just the base URL, so we reconstruct the project path.
    # In ACA-hosted mode, the user-assigned identity has Cognitive Services OpenAI User
    # on the account, so the base URL works directly.
    project_name = os.environ.get("FOUNDRY_PROJECT_NAME")
    raw_endpoint = os.environ.get(
        "AZURE_OPENAI_ENDPOINT",
        os.environ.get("FOUNDRY_PROJECT_ENDPOINT", ""),
    ).rstrip("/")

    base_endpoint = raw_endpoint.split("/api/projects")[0]

    if project_name and "/api/projects" not in raw_endpoint:
        # Hosted agent: runtime gives base URL only; reconstruct project-scoped path
        endpoint = f"{base_endpoint}/api/projects/{project_name}"
    elif "/api/projects" in raw_endpoint:
        # ACA-hosted: full project endpoint provided, strip for account-level access
        endpoint = base_endpoint
    else:
        # Standalone or explicit AZURE_OPENAI_ENDPOINT
        endpoint = base_endpoint

    deployment = os.environ.get("AZURE_AI_MODEL_DEPLOYMENT_NAME", "gpt-4.1")
    api_version = os.environ.get("AZURE_AI_API_VERSION", "2024-10-21")
    credential = build_credential()
    # Managed identities (hosted agent) require cognitiveservices audience;
    # ai.azure.com audience only works for user/delegated tokens.
    audience = os.environ.get(
        "AZURE_AI_TOKEN_AUDIENCE", "https://cognitiveservices.azure.com/.default"
    )
    token_provider = get_bearer_token_provider(credential, audience)
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
