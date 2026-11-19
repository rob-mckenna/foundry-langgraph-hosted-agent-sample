# Demo Script: LangGraph Claims Assistant -> Microsoft Foundry

## Demo goal
Show a health and life sciences payor audience that the **same LangGraph claims assistant** runs first as a standalone containerized API and then moves into **Microsoft Foundry** with only hosting-layer changes.

**Target length:** 15 minutes  
**Core message:** same graph, same tools, same prompt — different enterprise host.

> **Repo note for live prompts:** this sample is seeded with `CLM-1001`, `MBR-2001`, and `PLAN-A1`. If you want the exact stage language `MEM-2001` or `GOLD-PPO`, rename the sample data before the presentation. Use the repo-safe IDs below if you want a guaranteed working demo.

## Pre-demo setup (do this before the meeting)
- Confirm `.env` is populated for the host you plan to run.
- Run `az login` in the terminal you will use for the demo.
- Have these files open in tabs:
  - `src\claims_agent\graph.py`
  - `src\claims_agent\tools.py`
  - `src\claims_agent\prompts.py`
  - `src\standalone_api\app.py`
  - `src\aca_hosted\app.py`
  - `agent.yaml`
- If you want the container demo ready to go, pre-build once with Docker so you do not wait on package install during the meeting.

### Pre-demo commands
```powershell
python -m pip install -r requirements.txt
az login
$env:PYTHONPATH='src'
```

---

## 1) Opening (2 min)
**What to show:** title slide or README + terminal

**Speaker track**
> "We built a claims processing assistant using LangGraph. Let me show you how it runs standalone, then how easily it moves to Microsoft Foundry for enterprise hosting."
>
> "The use case is intentionally simple and familiar for a payor: claim status, member eligibility, and plan benefits. The point of the demo is not the domain complexity — it is the portability of the agent architecture."

**Presenter cues**
- Set audience expectation: this is the same agent in two hosting models.
- Say up front that the shared logic lives in one package and the host wrappers are thin.
- Frame Foundry as the enterprise landing zone, not a rewrite exercise.

**Optional terminal commands**
```powershell
Get-Content README.md
```

---

## 2) Shared Agent Walkthrough (3 min)
**What to show:** `src\claims_agent\graph.py`, then `tools.py`, then `prompts.py`

### `graph.py`
**Speaker track**
> "This is the reusable heart of the solution. `build_graph()` creates one LangGraph workflow that both hosts call."
>
> "The graph is simple and production-friendly: start at the agent, route to tools only when the model emits a tool call, then loop back to the agent until it can answer."

**Call out explicitly**
- `StateGraph(ClaimsAgentState)` is the shared workflow.
- `configured_model = (model or _build_default_model()).bind_tools(CLAIMS_TOOLS)` means the same tool contract is preserved in either host.
- The routing logic checks the last `AIMessage`; if there are tool calls, go to `tools`, otherwise end.
- This is what makes the agent portable: the host provides a model and runtime wrapper, but the graph stays the same.

### `tools.py`
**Speaker track**
> "There are five tools, and they map cleanly to common payor service scenarios including claim lookup, member claim search, eligibility, benefits, and prior authorization status."

**Call out explicitly**
- `lookup_claim_status(claim_id)`
- `search_claims_by_member(member_id)`
- `check_member_eligibility(member_id)`
- `get_benefit_summary(plan_code)`
- `get_prior_authorization_status(auth_id)`
- Each tool returns deterministic mock data so the demo is stable.

### `prompts.py`
**Speaker track**
> "The system prompt is also shared. The behavioral contract does not change when we move to Foundry."

**Call out explicitly**
- Role: claims processing assistant for a health insurance payor.
- Guardrails: use tool results as source of truth, ask for missing IDs, keep answers concise, do not invent policy details or medical advice.

**PowerShell commands for the walkthrough**
```powershell
Get-Content src\claims_agent\graph.py
Get-Content src\claims_agent\tools.py
Get-Content src\claims_agent\prompts.py
```

---

## 3) Standalone Demo (3 min)
**What to show:** start the API, make three requests, then briefly show Docker assets

### Start locally
```powershell
$env:PYTHONPATH='src'
python -m uvicorn standalone_api.app:app --app-dir src --host 0.0.0.0 --port 8080
```

### Live request 1: claim status
**Say:**
> "First, the agent is running as a simple standalone API in a container-friendly FastAPI wrapper."

**Working request**
```powershell
Invoke-RestMethod -Method Post -Uri http://localhost:8080/chat -ContentType 'application/json' -Body '{"message":"What is the status of claim CLM-1001?","thread_id":"demo-thread"}'
```

```bash
curl -s http://localhost:8080/chat -H "Content-Type: application/json" -d "{\"message\":\"What is the status of claim CLM-1001?\",\"thread_id\":\"demo-thread\"}"
```

**Expected talk track**
- Point out that the answer comes from the shared graph + tools.
- Mention that `CLM-1001` is seeded in the demo data.

### Live request 2: member eligibility
**Customer-facing phrasing requested:** "Is member MEM-2001 eligible for services?"  
**Repo-safe live prompt:** use `MBR-2001` unless sample data is relabeled.

```powershell
Invoke-RestMethod -Method Post -Uri http://localhost:8080/chat -ContentType 'application/json' -Body '{"message":"Is member MBR-2001 eligible for services?","thread_id":"demo-thread"}'
```

```bash
curl -s http://localhost:8080/chat -H "Content-Type: application/json" -d "{\"message\":\"Is member MBR-2001 eligible for services?\",\"thread_id\":\"demo-thread\"}"
```

### Live request 3: benefits summary
**Customer-facing phrasing requested:** "What are the benefits for plan GOLD-PPO?"  
**Repo-safe live prompt:** use `PLAN-A1` unless sample data is relabeled.

```powershell
Invoke-RestMethod -Method Post -Uri http://localhost:8080/chat -ContentType 'application/json' -Body '{"message":"What are the benefits for plan PLAN-A1?","thread_id":"demo-thread"}'
```

```bash
curl -s http://localhost:8080/chat -H "Content-Type: application/json" -d "{\"message\":\"What are the benefits for plan PLAN-A1?\",\"thread_id\":\"demo-thread\"}"
```

### Show Docker setup
**Speaker track**
> "Nothing exotic here — this can run as a normal containerized API before you are ready for a managed agent platform."

**Commands**
```powershell
Get-Content docker-compose.yml
Get-Content deployment\standalone\Dockerfile
```

**Call out explicitly**
- `docker-compose.yml` maps port `8080:8080`.
- `deployment\standalone\Dockerfile` starts `uvicorn standalone_api.app:app`.
- This is a normal standalone hosting pattern any engineering team can start with.
- **Demo tip:** Show the Docker files but don't run `docker compose up` live — `DefaultAzureCredential` needs `az login` which isn't available inside a Linux container on Windows. In production, Managed Identity handles this seamlessly. For the live demo, run locally (as shown above) where `az login` just works.

---

## 4) The Foundry Diff (5 min)
**What to show:** `src\standalone_api\app.py` next to `src\aca_hosted\app.py`, then `agent.yaml`

**Transition line**
> "Now the important part: moving to Foundry does not require us to rewrite the agent. We only change the hosting layer."

### Side-by-side story

| Concern | Standalone (`src\standalone_api\app.py`) | ACA/Foundry (`src\aca_hosted\app.py`) | What to say |
|---|---|---|---|
| Shared agent logic | `build_graph(model=build_chat_model(), checkpointer=MemorySaver())` | `graph = build_graph(model=model, checkpointer=MemorySaver())` | "Both hosts call the same `build_graph()` factory." |
| Model/auth flow | Direct Azure OpenAI settings: `AZURE_OPENAI_ENDPOINT` + `AZURE_OPENAI_DEPLOYMENT`; token scope is `ai.azure.com` | Foundry host settings: endpoint plus `AZURE_AI_MODEL_DEPLOYMENT_NAME`; token audience defaults to `cognitiveservices.azure.com` | "The config source changes, not the agent logic." |
| Server wrapper | FastAPI app with a `/chat` endpoint | `LangGraphHostedAgent(graph)` behind `ResponsesHostServer(agent).run(port=port)` | "Standalone is a custom REST wrapper; Foundry is a protocol-compliant agent host." |
| Session/state handling | `MemorySaver()` configured in the standalone process | `MemorySaver()` is still used, and `LangGraphHostedAgent` maps runtime session IDs to LangGraph thread IDs | "State is process-local and is not durable across restarts." |
| Deployment artifact | Container only | Root `agent.yaml` plus the shared `deployment\aca-hosted\Dockerfile` | "The root azd configuration deploys all three modes." |

### Specific lines to emphasize
**From `src\standalone_api\app.py`**
- `FastAPI(...)` creates a custom HTTP API.
- `build_chat_model()` authenticates directly to Azure OpenAI.
- `MemorySaver()` gives lightweight, process-local conversation continuity; it does not persist across restarts.
- `/chat` accepts `message` + `thread_id`.

**From `src\aca_hosted\app.py`**
- `build_foundry_model()` reads the endpoint, `AZURE_AI_MODEL_DEPLOYMENT_NAME`, and optional `AZURE_AI_API_VERSION` (default `2024-10-21`).
- `graph = build_graph(model=model, checkpointer=checkpointer)` is unchanged agent assembly with the same `MemorySaver()` pattern.
- `LangGraphHostedAgent.run(...)` translates Responses messages plus session IDs into a LangGraph invoke call.
- `ResponsesHostServer(agent).run(port=port)` swaps in the Foundry-native server, with `PORT` defaulting to `8088`.

### `agent.yaml`
**Speaker track**
> "This is the deployment contract for Foundry. The graph did not change; the packaging and runtime metadata did."

**Call out explicitly**
- `kind: hosted`
- `protocols: responses`
- `container.resources` and `startupCommand` configure the hosted runtime.
- The `claims-foundry-agent` service in `azure.yaml` references `agent.yaml` and sets the Dockerfile and runtime environment.

**PowerShell commands for this section**
```powershell
Get-Content src\standalone_api\app.py
Get-Content src\aca_hosted\app.py
Get-Content agent.yaml
git --no-pager diff --no-index src\standalone_api\app.py src\aca_hosted\app.py
```

### Optional Foundry local-host command
Use this only if you want to prove the Foundry host boots locally before deployment:

```powershell
$env:PYTHONPATH='src'
$env:PORT='8088'
python -m aca_hosted.app
```

**Important:** if `.env` still sets `PORT=8080` for Docker workflows, override it to `8088` in the demo shell before you launch the Foundry host.

### Optional Responses API example
If you have a deployed Foundry endpoint and want to show the protocol shape, use the deployment URL that Foundry gives you:

```bash
curl -s https://<your-foundry-endpoint>/responses -H "Content-Type: application/json" -H "Authorization: Bearer <token>" -d "{\"input\":\"What is the status of claim CLM-1001?\",\"stream\":false}"
```

```powershell
Invoke-RestMethod -Method Post -Uri https://<your-foundry-endpoint>/responses -Headers @{ Authorization = 'Bearer <token>' } -ContentType 'application/json' -Body '{"input":"What is the status of claim CLM-1001?","stream":false}'
```

---

## 5) Key Takeaways (2 min)
**Close with these exact ideas**
- **Zero changes** to the agent logic, tools, or prompt.
- **Foundry adds** managed sessions, scale, identity, and protocol compliance.
- The **same graph works in both worlds**.
- Teams can start with a standalone container and **adopt Foundry when they are ready**.

**Suggested closing track**
> "What you saw today was one agent, not two. We started with a standalone containerized host, then moved that same LangGraph workflow into Microsoft Foundry."
>
> "That means you can prototype quickly, prove business value, and adopt enterprise hosting later — without rewriting the core agent logic."

---

## One-page presenter cheat sheet
### Sequence
1. Opening message
2. `graph.py` -> `tools.py` -> `prompts.py`
3. Start standalone API
4. Run claim, eligibility, and benefits prompts
5. Show `docker-compose.yml` + standalone Dockerfile
6. Compare `standalone_api\app.py` vs `aca_hosted\app.py`
7. Show the root `agent.yaml`
8. Deliver takeaways

### Short fallback line if time runs short
> "The key point is simple: the LangGraph agent stays intact. Only the host changes when we move from standalone container hosting into Microsoft Foundry." 
