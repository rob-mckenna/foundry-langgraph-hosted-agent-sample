# LangGraph to Microsoft Foundry Migration Checklist

This repository demonstrates three hosts for one shared claims agent:

- **Standalone:** `src/standalone_api/app.py` exposes FastAPI `/chat` and `/chat/history`.
- **ACA-hosted:** `src/aca_hosted/app.py` exposes the OpenAI Responses protocol on port `8088`.
- **Foundry-hosted:** the same ACA host image is deployed as a Foundry hosted agent.

The graph, tools, prompts, and state definitions live under `src/claims_agent/` and are shared across the modes. The migration changes the host and model configuration, not the graph topology.

## What changes when moving to Foundry

1. **Keep the shared agent core.** Continue to build the graph with `claims_agent.graph.build_graph`; the tools and prompts remain shared.
2. **Use the hosted adapter.** `src/aca_hosted/app.py` wraps the graph in `LangGraphHostedAgent` and starts `ResponsesHostServer`. It maps the runtime session ID to LangGraph's `thread_id`.
3. **Configure model access.** Standalone uses `AZURE_OPENAI_ENDPOINT` and `AZURE_OPENAI_DEPLOYMENT`. The ACA/Foundry host uses `AZURE_AI_MODEL_DEPLOYMENT_NAME` and an Azure endpoint supplied through `AZURE_OPENAI_ENDPOINT` or `FOUNDRY_PROJECT_ENDPOINT`. The app strips `/api/projects/...` for ACA account-level access and reconstructs the project path when `FOUNDRY_PROJECT_NAME` is supplied with a base endpoint. `AZURE_AI_API_VERSION` defaults to `2024-10-21`.
4. **Use the Foundry definition and image.** The root `azure.yaml` references the hosted-agent definition in `agent.yaml` and configures its runtime environment; `deployment/aca-hosted/Dockerfile` is shared by the ACA and Foundry modes.
5. **Deploy from the repository root.** The root `azure.yaml` is canonical. `azd up` provisions `infra/bicep` and deploys the standalone Container App, ACA-hosted Container App, and Foundry hosted agent.

## Runtime and state notes

The ACA-hosted endpoint has no application-level caller authentication; secure its ingress or place it behind an authenticated gateway. Foundry handles caller authentication at the platform boundary. The app obtains Azure credentials through `DefaultAzureCredential`, using managed identity in Azure and developer credentials locally.

Both hosts currently use LangGraph's in-memory `MemorySaver`. Mapping a session ID to `thread_id` allows follow-up turns to share state while the process and checkpointer remain alive, but it does not make checkpoints durable or survive process restarts.

## Quick local setup

Install dependencies, authenticate with Azure, and set `PYTHONPATH=src`. Run standalone with:

```bash
python -m uvicorn standalone_api.app:app --app-dir src --host 0.0.0.0 --port 8080
```

Run the ACA/Foundry host locally with:

```bash
PORT=8088 python -m aca_hosted.app
```

Set `USE_MANAGED_IDENTITY=false` for local development. Configure `FOUNDRY_PROJECT_ENDPOINT` and `AZURE_AI_MODEL_DEPLOYMENT_NAME` for the ACA/Foundry host; Azure deployments configure the managed identity and endpoint through the Bicep template and Foundry runtime.

## Dependencies

The relevant hosting dependencies are declared in `requirements.txt`: `langchain-azure-ai`, `agent-framework-foundry-hosting`, `azure-ai-projects`, and `azure-identity`, alongside LangGraph and LangChain. Use the repository's pinned ranges rather than copying package versions from older migration examples.

## Customer checklist

- Keep the graph, tools, prompts, and state in the shared agent package.
- Add an adapter that implements the Foundry hosted-agent protocol.
- Map the Foundry session identifier to the LangGraph thread identifier.
- Return the protocol response type expected by the Responses host.
- Configure model endpoint, deployment, and managed identity for the target host.
- Package the host in the ACA image and declare the agent in the root `agent.yaml`.
- Deploy through root `azure.yaml`; validate that any external ACA ingress is protected appropriately.
- Choose a durable checkpointer if conversation state must survive process restarts.

## Official Microsoft references

- [Use LangGraph with the Agent Service](https://learn.microsoft.com/en-us/azure/foundry/how-to/develop/langchain-agents)
- [Host LangGraph agents as Foundry hosted agents](https://learn.microsoft.com/en-us/azure/foundry/how-to/develop/langchain-hosted-agents)
- [Documentation source](https://github.com/MicrosoftDocs/azure-ai-docs/blob/main/articles/foundry/how-to/develop/langchain-agents.md)
- [Video: Host your agents on Foundry — LangChain + LangGraph](https://www.youtube.com/watch?v=mFZHq5mTt0A)
