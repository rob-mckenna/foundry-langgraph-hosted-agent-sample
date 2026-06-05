# Claims Status Inquiry Agent Demo

This sample implements one LangGraph-powered claims inquiry assistant and exposes it in two hosting models:

- **Standalone**: FastAPI + Docker with a simple `/chat` endpoint
- **Microsoft Foundry**: `ResponsesHostServer` wrapping the same shared graph

The demo message is straightforward: **same graph, same tools, different hosting surface**.

## Use case
The assistant acts as a **Claims Processing Assistant** for a health insurance payor. It can:

- look up claim status by claim ID
- check member eligibility by member ID
- provide benefit summaries by plan code

All answers use deterministic mock data so the demo stays stable and repeatable.

## Project layout
```text
foundry-langgraph-hosted-agent-sample/
├─ README.md
├─ pyproject.toml
├─ requirements.txt
├─ .env.example
├─ docker-compose.yml
├─ src/
│  ├─ claims_agent/
│  │  ├─ __init__.py
│  │  ├─ data_access.py
│  │  ├─ graph.py
│  │  ├─ models.py
│  │  ├─ prompts.py
│  │  ├─ sample_data.py
│  │  ├─ state.py
│  │  └─ tools.py
│  ├─ standalone_api/
│  │  ├─ __init__.py
│  │  └─ app.py
│  └─ foundry_host/
│     ├─ __init__.py
│     └─ app.py
├─ deployment/
│  ├─ standalone/
│  │  └─ Dockerfile
│  └─ foundry/
│     ├─ agent.manifest.yaml
│     ├─ Dockerfile
│     └─ azd/
├─ docs/
│  └─ demo-script.md
└─ tests/
```

## Shared agent design
The shared package under `src\claims_agent\` contains:

- a `StateGraph` tool-calling loop
- the payor-specific system prompt
- deterministic claims, members, and benefits data
- three tools for claim status, eligibility, and benefits

Both hosts call the same `build_graph()` factory so behavior stays aligned.

## Environment configuration
Copy `.env.example` to `.env`, run `az login`, and populate the settings for the host you want to run.

### Azure OpenAI with DefaultAzureCredential (standalone host)
```env
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com
AZURE_OPENAI_DEPLOYMENT=gpt-4.1-mini
```

### Foundry with DefaultAzureCredential (Foundry host)
```env
FOUNDRY_PROJECT_ENDPOINT=https://your-project.services.ai.azure.com/api/projects/your-project
AZURE_AI_MODEL_DEPLOYMENT_NAME=gpt-4.1
```

## Local setup
Install dependencies:

```bash
python -m pip install -r requirements.txt
az login
```

Set the Python path so imports resolve from `src/`:

```powershell
# PowerShell
$env:PYTHONPATH='src'
```

```bash
# Bash / macOS / Linux
export PYTHONPATH=src
```

## Run the standalone API locally
```powershell
python -m uvicorn standalone_api.app:app --app-dir src --host 0.0.0.0 --port 8080
```

Send a request:

```powershell
Invoke-RestMethod -Method Post -Uri http://localhost:8080/chat -ContentType 'application/json' -Body '{"message":"What is the status of claim CLM-1001?","thread_id":"demo-thread-1"}'
```

## Run with Docker Compose
```powershell
docker compose up --build
```

The standalone container listens on `http://localhost:8080`.

## Run the Foundry host locally
```powershell
python -m foundry_host.app
```

This keeps the shared LangGraph agent intact and only changes host concerns such as authentication and the `ResponsesHostServer` wrapper.

## Tests
```powershell
$env:PYTHONPATH='src'
python -m pytest
```

## What changes between the two variants?
### Shared across both
- `src\claims_agent\graph.py`
- `src\claims_agent\tools.py`
- `src\claims_agent\prompts.py`
- deterministic sample data and lookup layer

### Different for each host
- `src\standalone_api\app.py` handles REST requests and `MemorySaver`
- `src\foundry_host\app.py` handles Foundry auth and `ResponsesHostServer`
- deployment assets under `deployment\standalone\` and `deployment\foundry\`

## Demo narrative
1. Start in `src\claims_agent\graph.py` and explain the reusable graph.
2. Show `src\standalone_api\app.py` as the baseline containerized deployment.
3. Show `src\foundry_host\app.py` and `deployment\foundry\agent.manifest.yaml` as the Foundry-specific delta.
4. Close with the core message: **the agent logic did not need to be rewritten to move into Foundry hosting**.

## Official Microsoft references

- [Use LangGraph with the Agent Service](https://learn.microsoft.com/en-us/azure/foundry/how-to/develop/langchain-agents) — Integrating LangGraph agents into Foundry's Agent Service
- [Host LangGraph agents as Foundry hosted agents](https://learn.microsoft.com/en-us/azure/foundry/how-to/develop/langchain-hosted-agents) — The `ResponsesHostServer` hosting pattern and protocol
- [Source docs on GitHub](https://github.com/MicrosoftDocs/azure-ai-docs/blob/main/articles/foundry/how-to/develop/langchain-agents.md) — Markdown source for the above
- [Video: Host your agents on Foundry — LangChain + LangGraph](https://www.youtube.com/watch?v=mFZHq5mTt0A) — Video walkthrough
