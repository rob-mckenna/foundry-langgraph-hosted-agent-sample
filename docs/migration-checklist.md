# LangGraph to Microsoft Foundry Hosted Agent Migration Checklist

This is the **exact migration path** shown in this repo:

- **Before:** `src/standalone_api/app.py` — LangGraph agent exposed as a custom FastAPI `/chat` endpoint in a container
- **After:** `src/foundry_host/app.py` — the **same LangGraph graph** wrapped for Microsoft Foundry hosted-agent runtime

Use this as the step-by-step checklist for taking an existing LangGraph agent and making it run in **MS Foundry as a hosted agent**.

---

## Executive summary

**You are not rewriting the agent.**
You are mainly:

1. adding the Foundry hosting packages,
2. wrapping your compiled LangGraph graph in a small adapter class,
3. replacing your custom HTTP API with Foundry's hosting surface,
4. changing the environment variables used to find the model endpoint,
5. adding a Foundry manifest, and
6. packaging the container with the Foundry entrypoint.

The **graph, tools, prompts, state, and business logic stay the same**.

---

## 1. Add the Foundry hosting dependencies

### What changes
Your standalone LangGraph container needs the Foundry hosting/runtime packages in addition to the normal LangGraph + Azure identity packages.

### Required packages shown in this repo
From `requirements.txt`:

```txt
langchain-azure-ai>=0.1.2,<1.0
agent-framework-foundry-hosting>=1.0.0a260528,<2.0
azure-ai-projects>=1.0.0b8,<2.0
azure-identity>=1.20,<2.0
```

### Practical migration diff
If your existing app only had the standard LangGraph/OpenAI dependencies, the migration looks like this:

```diff
 langgraph>=0.2.60,<1.1
 langchain-core>=0.3.40,<1.0
 langchain-openai>=0.2.10,<1.0
+langchain-azure-ai>=0.1.2,<1.0
+agent-framework-foundry-hosting>=1.0.0a260528,<2.0
+azure-ai-projects>=1.0.0b8,<2.0
 azure-identity>=1.20,<2.0
```

### Why
These packages provide the **Foundry hosting runtime** and the compatibility layer used by `ResponsesHostServer`.

---

## 2. Keep the LangGraph graph exactly as-is

### What stays the same
The core agent implementation is unchanged. In this repo, both hosting models use the same graph builder:

```python
from claims_agent.graph import build_graph
```

And the graph itself is still compiled the same way:

```python
checkpointer = MemorySaver()
graph = build_graph(model=model, checkpointer=checkpointer)
```

### Actual unchanged core logic
These files do **not** need a Foundry-specific rewrite:

- `src/claims_agent/graph.py`
- `src/claims_agent/tools.py`
- `src/claims_agent/prompts.py`
- `src/claims_agent/state.py`

### Why
Foundry is changing the **hosting surface**, not the **agent brain**.

---

## 3. Replace your custom FastAPI app with a Foundry adapter class

### Before: custom HTTP app
`src/standalone_api/app.py` exposes a FastAPI app and defines request/response models:

```python
app = FastAPI(title="Claims Status Inquiry API", version="0.1.0")

class ChatRequest(BaseModel):
    message: str = Field(min_length=1)
    thread_id: str = Field(min_length=1)

class ChatResponse(BaseModel):
    thread_id: str
    response: str
```

### After: Foundry adapter
`src/foundry_host/app.py` replaces that HTTP surface with an adapter object:

```python
class LangGraphHostedAgent:
    def __init__(self, graph: Any) -> None:
        self._graph = graph
        self.id = "claims-status-inquiry-agent"
        self.name = "Claims Status Inquiry Agent"
        self.description = "A claims processing assistant for health insurance payors."
```

### Practical migration diff

```diff
-from fastapi import FastAPI
-from pydantic import BaseModel, Field
-
-app = FastAPI(title="Claims Status Inquiry API", version="0.1.0")
-
-class ChatRequest(BaseModel):
-    message: str = Field(min_length=1)
-    thread_id: str = Field(min_length=1)
-
-class ChatResponse(BaseModel):
-    thread_id: str
-    response: str
+from agent_framework import AgentResponse, AgentSession, Message
+
+class LangGraphHostedAgent:
+    def __init__(self, graph: Any) -> None:
+        self._graph = graph
+        self.id = "claims-status-inquiry-agent"
+        self.name = "Claims Status Inquiry Agent"
+        self.description = "A claims processing assistant for health insurance payors."
```

### Why
Foundry does **not** want your custom `/chat` route. It wants an agent object that implements the hosted-agent protocol.

---

## 4. Implement the protocol methods Foundry needs

### What changes
Your hosted agent needs three key methods:

1. `run(...)`
2. `create_session(...)`
3. `get_session(...)`

### Exact code from this repo

```python
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
    ...


def create_session(self, *, session_id: str | None = None) -> AgentSession:
    return AgentSession(session_id=session_id)


def get_session(self, service_session_id: str, *, session_id: str | None = None) -> AgentSession:
    return AgentSession(service_session_id=service_session_id, session_id=session_id)
```

### Why
This is the contract that lets Foundry create/resume sessions and call your agent.

---

## 5. Translate Foundry messages into the same LangGraph invocation you already use

### Before: your API receives a plain request model
In the standalone app, the API endpoint directly uses the inbound request values:

```python
result = graph.invoke(
    {"messages": [HumanMessage(content=request.message)]},
    config={"configurable": {"thread_id": request.thread_id}},
)
```

### After: parse Foundry message objects, then invoke the same graph
In the hosted app, the adapter extracts text from Foundry message payloads and maps the Foundry session to the LangGraph `thread_id`:

```python
thread_id = session.service_session_id if session and session.service_session_id else str(uuid.uuid4())
result = self._graph.invoke(
    {"messages": [HumanMessage(content=user_text)]},
    config={"configurable": {"thread_id": thread_id}},
)
```

### Practical migration diff

```diff
-result = graph.invoke(
-    {"messages": [HumanMessage(content=request.message)]},
-    config={"configurable": {"thread_id": request.thread_id}},
-)
+thread_id = session.service_session_id if session and session.service_session_id else str(uuid.uuid4())
+result = self._graph.invoke(
+    {"messages": [HumanMessage(content=user_text)]},
+    config={"configurable": {"thread_id": thread_id}},
+)
```

### Why
The **graph call itself barely changes**. The main difference is just where the input text and conversation ID come from.

---

## 6. Return a Foundry `AgentResponse` instead of your own JSON response model

### Before: custom API response model

```python
return ChatResponse(
    thread_id=request.thread_id,
    response=_extract_response_text(result["messages"]),
)
```

### After: Foundry response object

```python
return AgentResponse(
    messages=[Message("assistant", [response_text])],
    response_id=f"resp_{uuid.uuid4().hex[:16]}",
)
```

### Practical migration diff

```diff
-return ChatResponse(
-    thread_id=request.thread_id,
-    response=_extract_response_text(result["messages"]),
-)
+return AgentResponse(
+    messages=[Message("assistant", [response_text])],
+    response_id=f"resp_{uuid.uuid4().hex[:16]}",
+)
```

### Why
Foundry expects the hosted agent to return its own message envelope, not your app-specific JSON schema.

---

## 7. Switch model configuration from standalone Azure OpenAI env vars to Foundry env vars

### Before: standalone container env vars
The standalone API expects:

```python
endpoint = os.getenv("AZURE_OPENAI_ENDPOINT", "").strip().rstrip("/")
deployment = os.getenv("AZURE_OPENAI_DEPLOYMENT", "").strip()
```

### After: Foundry-hosted env vars
The Foundry host expects:

```python
endpoint = os.environ["FOUNDRY_PROJECT_ENDPOINT"].rstrip("/")
deployment = os.environ.get("AZURE_AI_MODEL_DEPLOYMENT_NAME", "gpt-4.1")
api_version = os.environ.get("AZURE_AI_API_VERSION", "2024-12-01-preview")
```

### Practical migration diff

```diff
-endpoint = os.getenv("AZURE_OPENAI_ENDPOINT", "").strip().rstrip("/")
-deployment = os.getenv("AZURE_OPENAI_DEPLOYMENT", "").strip()
-if not endpoint or not deployment:
-    raise RuntimeError(
-        "Standalone API requires AZURE_OPENAI_ENDPOINT and AZURE_OPENAI_DEPLOYMENT. Run az login before starting the API."
-    )
+endpoint = os.environ["FOUNDRY_PROJECT_ENDPOINT"].rstrip("/")
+deployment = os.environ.get("AZURE_AI_MODEL_DEPLOYMENT_NAME", "gpt-4.1")
+api_version = os.environ.get("AZURE_AI_API_VERSION", "2024-12-01-preview")
```

### What the customer must configure
At minimum, based on `deployment/foundry/agent.manifest.yaml`:

- `FOUNDRY_PROJECT_ENDPOINT` (**required**)
- `AZURE_AI_MODEL_DEPLOYMENT_NAME` (**required in manifest**)
- `PORT` (optional)

Also supported in code:

- `AZURE_AI_API_VERSION` (optional, default is `2024-12-01-preview`)

### Why
In Foundry, the hosted runtime points the agent at the **Foundry project endpoint**, not the standalone app's direct Azure OpenAI endpoint configuration.

---

## 8. Replace the web server entrypoint with the Foundry host server

### Before: FastAPI + Uvicorn

```python
@app.post("/chat", response_model=ChatResponse)
def chat(request: ChatRequest) -> ChatResponse:
    ...
```

Docker command:

```dockerfile
CMD ["python", "-m", "uvicorn", "standalone_api.app:app", "--app-dir", "src", "--host", "0.0.0.0", "--port", "8080"]
```

### After: `ResponsesHostServer`

```python
def main() -> None:
    model = build_foundry_model()
    checkpointer = MemorySaver()
    graph = build_graph(model=model, checkpointer=checkpointer)
    agent = LangGraphHostedAgent(graph)
    port = int(os.environ.get("PORT", "8088"))
    ResponsesHostServer(agent).run(port=port)
```

Docker command:

```dockerfile
CMD ["python", "-m", "foundry_host.app"]
```

### Practical migration diff

```diff
-@app.post("/chat", response_model=ChatResponse)
-def chat(request: ChatRequest) -> ChatResponse:
-    ...
+def main() -> None:
+    model = build_foundry_model()
+    checkpointer = MemorySaver()
+    graph = build_graph(model=model, checkpointer=checkpointer)
+    agent = LangGraphHostedAgent(graph)
+    port = int(os.environ.get("PORT", "8088"))
+    ResponsesHostServer(agent).run(port=port)
```

### Why
Foundry wants your container to start an **agent host**, not a generic web API.

---

## 9. Add the Foundry manifest file

### What changes
A standalone container is not enough by itself. Foundry also needs a manifest that tells it how to run the agent.

### Exact file from this repo
`deployment/foundry/agent.manifest.yaml`

```yaml
schema_version: 1
name: claims-status-inquiry-agent
description: Shared LangGraph claims processing assistant hosted in Microsoft Foundry.
runtime:
  type: container
  dockerfile: deployment/foundry/Dockerfile
  port: 8088
hosting:
  protocol: responses
  entrypoint: python -m foundry_host.app
environment:
  required:
    - FOUNDRY_PROJECT_ENDPOINT
    - AZURE_AI_MODEL_DEPLOYMENT_NAME
  optional:
    - PORT
```

### Why
This is what makes the container a **Foundry hosted agent** instead of just “some Python image.”

---

## 10. Update the Dockerfile for Foundry hosting

### Before: standalone Dockerfile
`deployment/standalone/Dockerfile`

```dockerfile
EXPOSE 8080
CMD ["python", "-m", "uvicorn", "standalone_api.app:app", "--app-dir", "src", "--host", "0.0.0.0", "--port", "8080"]
```

### After: Foundry Dockerfile
`deployment/foundry/Dockerfile`

```dockerfile
EXPOSE 8088
CMD ["python", "-m", "foundry_host.app"]
```

### Practical migration diff

```diff
-EXPOSE 8080
-CMD ["python", "-m", "uvicorn", "standalone_api.app:app", "--app-dir", "src", "--host", "0.0.0.0", "--port", "8080"]
+EXPOSE 8088
+CMD ["python", "-m", "foundry_host.app"]
```

### What stays the same
The base image, working directory, `requirements.txt` install, and source copy pattern are unchanged:

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
```

---

## 11. Preserve conversation memory by mapping Foundry sessions to LangGraph thread IDs

### What changes
In the standalone API, the caller explicitly passes `thread_id`.
In Foundry hosting, the runtime manages the session, so the adapter maps the Foundry session ID into the graph config.

### Exact code from this repo

```python
thread_id = session.service_session_id if session and session.service_session_id else str(uuid.uuid4())
result = self._graph.invoke(
    {"messages": [HumanMessage(content=user_text)]},
    config={"configurable": {"thread_id": thread_id}},
)
```

### Why
This is the key step that preserves the same LangGraph checkpointing/memory behavior after migration.

---

## What You DON'T Need to Change

For a customer migration, these are the reassuring parts:

### You do **not** need to change the graph topology
This repo still uses the same `build_graph(...)` function in both deployment models.

### You do **not** need to rewrite tools
`lookup_claim_status`, `check_member_eligibility`, and `get_benefit_summary` remain unchanged in `src/claims_agent/tools.py`.

### You do **not** need to rewrite prompts
The same `CLAIMS_ASSISTANT_SYSTEM_PROMPT` is used.

### You do **not** need to redesign state
`ClaimsAgentState(MessagesState)` stays the same.

### You do **not** need to change your business logic
Anything in your tool/data-access layer can stay as-is as long as it already works in the container.

### You do **not** need to change how the graph is invoked internally
It is still a LangGraph invocation with `HumanMessage(...)` plus a configurable `thread_id`.

---

## One-page customer checklist

If you only have 15 minutes, this is the migration story:

1. **Keep your existing LangGraph graph, tools, prompts, and state.**
2. **Add Foundry runtime packages** (`agent-framework-foundry-hosting`, `azure-ai-projects`, `langchain-azure-ai`).
3. **Create a small adapter class** around your compiled graph.
4. **Implement** `run`, `create_session`, and `get_session`.
5. **Extract Foundry input messages** and map the Foundry session ID to LangGraph `thread_id`.
6. **Return `AgentResponse`** instead of your custom JSON schema.
7. **Swap env vars** from `AZURE_OPENAI_ENDPOINT` / `AZURE_OPENAI_DEPLOYMENT` to `FOUNDRY_PROJECT_ENDPOINT` / `AZURE_AI_MODEL_DEPLOYMENT_NAME`.
8. **Replace Uvicorn/FastAPI entrypoint** with `ResponsesHostServer(agent).run(...)`.
9. **Add `agent.manifest.yaml`** so Foundry knows how to run the container.
10. **Update the Dockerfile** to start `python -m foundry_host.app` on the Foundry port.

---

## Official Microsoft references

- [Use LangGraph with the Agent Service](https://learn.microsoft.com/en-us/azure/foundry/how-to/develop/langchain-agents) — Integrating LangGraph agents into Foundry's Agent Service
- [Host LangGraph agents as Foundry hosted agents](https://learn.microsoft.com/en-us/azure/foundry/how-to/develop/langchain-hosted-agents) — The `ResponsesHostServer` hosting pattern and protocol
- [Source docs on GitHub](https://github.com/MicrosoftDocs/azure-ai-docs/blob/main/articles/foundry/how-to/develop/langchain-agents.md) — Markdown source for the above
- [Video: Host your agents on Foundry — LangChain + LangGraph](https://www.youtube.com/watch?v=mFZHq5mTt0A) — Video walkthrough
- Key package: `pip install -U "langchain-azure-ai[hosting,tools,opentelemetry]>=1.2.4"`

---

## Bottom line

For this repo, the migration to MS Foundry is **mostly a hosting adaptation, not an agent rewrite**.

If a customer already has a working LangGraph agent in a container, the work is usually:

- **wrap the graph**,
- **adopt the Foundry protocol**,
- **change config/entrypoint/manifest**,
- and **leave the core agent logic alone**.
