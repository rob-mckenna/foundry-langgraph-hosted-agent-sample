# Claims Status Inquiry Agent Demo

One LangGraph-powered claims inquiry assistant. Three hosting surfaces. The agent core is identical across all three.

## Use case

The assistant acts as a **Claims Processing Assistant** for a health insurance payor. It can:

- look up claim status by claim ID
- search all claims for a member by member ID
- check member eligibility by member ID
- provide benefit summaries by plan code
- check prior authorization status by authorization ID

All answers use deterministic mock data so the demo stays stable and repeatable.

## Three deployment modes

| | Standalone | ACA-Hosted | Foundry Hosted Agent |
|---|---|---|---|
| **Framework** | FastAPI | Agent Framework + Foundry Hosting adapter | Agent Framework + Foundry Hosting adapter |
| **Protocol** | Custom `/chat` + `/chat/history` | OpenAI Responses API (`/responses`) | OpenAI Responses API (`/responses`) |
| **Auth to caller** | None (open endpoint) | Bearer token (you validate) | Bearer token (platform validates) |
| **Model connection** | Direct Azure OpenAI endpoint | Via Foundry project (account-level access) | Via Foundry project (project-scoped access) |
| **Identity** | User-assigned managed identity | User-assigned managed identity | Platform-managed agent identity |
| **Infrastructure** | Azure Container Apps (you manage) | Azure Container Apps (you manage) | Foundry Agent Service (platform manages) |
| **Session management** | Client provides `thread_id` | Automatic `agent_session_id` | Automatic `agent_session_id` + platform persistence |
| **Foundry portal** | Not visible | Not visible | Visible (playground, monitoring, versioning) |
| **Entry point** | `standalone_api/app.py` | `aca_hosted/app.py` | `aca_hosted/app.py` (same image) |

### Mode 1 — Standalone
FastAPI + LangGraph on Azure Container Apps, calling Azure OpenAI directly.
- Entry point: `src\standalone_api\app.py`
- Port: `8080`
- Endpoints: `POST /chat`, `GET /chat/history`

### Mode 2 — ACA-Hosted
Agent Framework + LangGraph on Azure Container Apps, calling models via a Microsoft Foundry project endpoint.
- Entry point: `src\aca_hosted\app.py`
- Port: `8088`
- Endpoint: `POST /responses` (OpenAI Responses protocol)

### Mode 3 — Foundry Hosted Agent
Same `aca_hosted/app.py` code deployed to Microsoft Foundry Agent Service. The platform manages infrastructure, versioning, session isolation, and portal integration.
- Entry point: `src\aca_hosted\app.py` (same image as ACA-Hosted)
- Manifest: `agent.yaml`
- Endpoint: Foundry Agent Service URL (platform-assigned)

## What changes between modes?

### `src\claims_agent\graph.py` is **identical** across all three.

So are `tools.py`, `prompts.py`, `state.py`, and the deterministic sample data. The agent core never changes.

### What is different

**Standalone → ACA-Hosted**

| What changes | Details |
|---|---|
| Host file | `standalone_api/app.py` → `aca_hosted/app.py` |
| Model connection | Direct `AzureOpenAI` client → `AIProjectClient` via Foundry project endpoint |
| Protocol | `/chat` REST → `/responses` (OpenAI Responses API) |
| Session management | Client-supplied `thread_id` → automatic `agent_session_id` |
| New code | `LangGraphHostedAgent` adapter (~60 lines) + `ResponsesHostServer(agent)` wrapper |

**ACA-Hosted → Foundry Hosted Agent**

| What changes | Details |
|---|---|
| Infrastructure | You manage the Container App | Platform manages the agent runtime |
| Auth | You validate Bearer tokens | Platform validates, agent identity is project-scoped |
| Code | None — same Dockerfile, same `aca_hosted/app.py` |
| Extras | Add `agent.yaml` manifest; register via `azd up` or `scripts/register-hosted-agent.sh` |

The migration narrative: **start standalone → connect to a Foundry project → let Foundry host it**. Each step is incremental. The graph never changes.

## Project layout

```text
foundry-langgraph-hosted-agent-sample\
├─ README.md
├─ agent.yaml                          ← Foundry Hosted Agent manifest
├─ azure.yaml                          ← azd config (all three services)
├─ pyproject.toml
├─ requirements.txt
├─ .env.example
├─ docker-compose.yml
├─ src\
│  ├─ claims_agent\                    ← shared agent core (unchanged across all modes)
│  │  ├─ graph.py
│  │  ├─ tools.py
│  │  ├─ prompts.py
│  │  ├─ state.py
│  │  ├─ data_access.py
│  │  ├─ models.py
│  │  └─ sample_data.py
│  ├─ standalone_api\
│  │  └─ app.py                        ← Mode 1 host
│  └─ aca_hosted\
│     └─ app.py                        ← Mode 2 + Mode 3 host (same image)
├─ deployment\
│  ├─ standalone\
│  │  └─ Dockerfile                    ← standalone container
│  └─ aca-hosted\
│     ├─ Dockerfile                    ← ACA-Hosted + Foundry Hosted Agent container
│     └─ agent.manifest.yaml
├─ infra\
│  └─ bicep\
│     └─ main.bicep                    ← Azure infrastructure (IaC)
├─ frontend\
│  ├─ index.html
│  ├─ styles.css
│  └─ app.js
├─ scripts\
│  ├─ clean-env.sh                     ← azd predeploy hook (posix)
│  ├─ clean-env.ps1                    ← azd predeploy hook (windows)
│  └─ register-hosted-agent.sh
└─ tests\                              ← pytest suite (21 tests)
```

## Environment configuration

Copy `.env.example` to `.env` and `az login`.

### Standalone

```env
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com
AZURE_OPENAI_DEPLOYMENT=gpt-4.1-mini
```

### ACA-Hosted and Foundry Hosted Agent

```env
FOUNDRY_PROJECT_ENDPOINT=https://your-account.services.ai.azure.com/api/projects/your-project
AZURE_AI_MODEL_DEPLOYMENT_NAME=gpt-4.1
PORT=8088
USE_MANAGED_IDENTITY=false
```

> **Docker note:** `DefaultAzureCredential` relies on the host's `az login` token cache, which is DPAPI-encrypted and unavailable inside a Linux container on Windows. For local development, run without Docker. For local Docker testing, set service principal vars in `.env`:
> ```
> AZURE_TENANT_ID=<tenant-id>
> AZURE_CLIENT_ID=<sp-client-id>
> AZURE_CLIENT_SECRET=<sp-secret>
> ```
>
> **Managed identity note:** local machines and local Docker containers cannot use Azure IMDS at `169.254.169.254`. Leave `USE_MANAGED_IDENTITY=false` for local development. Azure deployments set `USE_MANAGED_IDENTITY=true` so the app can use the configured Container Apps or Foundry Hosted Agent identity.

## Local development

Install dependencies and set the Python path:

```bash
python -m pip install -r requirements.txt
az login
```

```powershell
# PowerShell
$env:PYTHONPATH='src'
```

```bash
# Bash / macOS / Linux
export PYTHONPATH=src
```

### Run standalone locally (Mode 1)

```bash
python -m uvicorn standalone_api.app:app --app-dir src --host 0.0.0.0 --port 8080
```

### Run ACA-Hosted locally (Mode 2)

```bash
export PORT=8088
python -m aca_hosted.app
```

## Deploy to Azure

`azd up` provisions infrastructure and deploys all three services in one command:

```bash
azd auth login
azd up
```

The `azure.yaml` defines three services: `claims-standalone-agent` (Container App), `claims-aca-agent` (Container App), and `claims-foundry-agent` (Foundry Agent Service). The Bicep in `infra\bicep\main.bicep` handles permissions, managed identities, Foundry connections, and ACR wiring.

## Testing deployed services

```bash
# Standalone
curl -s -X POST https://<standalone-app>.azurecontainerapps.io/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What is the status of claim CLM-1001?", "thread_id": "test-1"}' | jq .

# ACA-Hosted
TOKEN=$(az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv)
curl -s -X POST https://<aca-app>.azurecontainerapps.io/responses \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"input": "What is the status of claim CLM-1001?"}' | jq .

# Foundry Hosted Agent
curl -s -X POST "https://<account>.services.ai.azure.com/api/projects/<project>/agents/<agent>/endpoint/protocols/openai/responses?api-version=v1" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"input": "What is the status of claim CLM-1001?"}' | jq .
```

## Running tests locally

```bash
export PYTHONPATH=src
python -m pytest
```

```powershell
# PowerShell
$env:PYTHONPATH='src'
python -m pytest
```

## Frontend demo

The static frontend in `frontend\` talks to the standalone API at `http://localhost:8080/chat`.

```bash
cd frontend
python3 -m http.server 8000
```

Open `http://localhost:8000` in a browser, or open `frontend\index.html` directly.

## Official references

- [Use LangGraph with the Agent Service](https://learn.microsoft.com/en-us/azure/foundry/how-to/develop/langchain-agents) — Integrating LangGraph agents into Foundry's Agent Service
- [Host LangGraph agents as Foundry hosted agents](https://learn.microsoft.com/en-us/azure/foundry/how-to/develop/langchain-hosted-agents) — The `ResponsesHostServer` hosting pattern and protocol
- [Source docs on GitHub](https://github.com/MicrosoftDocs/azure-ai-docs/blob/main/articles/foundry/how-to/develop/langchain-agents.md) — Markdown source for the above
- [Video: Host your agents on Foundry — LangChain + LangGraph](https://www.youtube.com/watch?v=mFZHq5mTt0A) — Video walkthrough
