import os

from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from langchain_openai import ChatOpenAI

try:
    from langchain_azure_ai.agents.hosting import ResponsesHostServer
except ImportError:  # pragma: no cover - compatibility fallback for current package layout.
    from agent_framework_foundry_hosting import ResponsesHostServer

from claims_agent.graph import build_graph

_AZURE_AI_SCOPE = "https://ai.azure.com/.default"


def build_foundry_model() -> ChatOpenAI:
    endpoint = os.environ["FOUNDRY_PROJECT_ENDPOINT"].rstrip("/")
    deployment = os.environ.get("AZURE_AI_MODEL_DEPLOYMENT_NAME", "gpt-4.1")
    credential = DefaultAzureCredential()
    project = AIProjectClient(endpoint=endpoint, credential=credential)
    openai_client = project.get_openai_client()
    token_provider = get_bearer_token_provider(credential, _AZURE_AI_SCOPE)
    return ChatOpenAI(
        model=deployment,
        base_url=str(openai_client.base_url),
        api_key=token_provider,
    )


def main() -> None:
    model = build_foundry_model()
    graph = build_graph(model=model)
    port = int(os.environ.get("PORT", "8088"))
    ResponsesHostServer(graph).run(port=port)


if __name__ == "__main__":
    main()
