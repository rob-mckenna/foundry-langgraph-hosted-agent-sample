# Squad Decisions

## Active Decisions

### Holtzmann Architecture Decision (2026-06-05)

**Status:** Approved

Design a simple demo that shows one claims status inquiry agent implemented once in LangGraph, then exposed in two hosting models:
1. standalone FastAPI + Docker
2. Microsoft Foundry hosted agent service

**Key decisions:**
1. Keep one shared agent package (`src\claims_agent\`)
2. Separate hosting adapters from business logic (`src\standalone_api\app.py`, `src\foundry_host\app.py`)
3. Use simple, deterministic payor tools (claim status, eligibility, benefits)
4. Use one graph factory for both variants
5. Keep prompts and domain language in shared files
6. Make deployment assets runtime-specific (Docker for standalone, manifest/bicep for Foundry)
7. Optimize the demo for side-by-side diff (show what stays the same vs. what changes)

**Proposed structure:** Single shared agent core + thin runtime adapters for standalone and Foundry hosting.

### Gozer Frontend Decision (2026-06-13)

**Status:** Approved

Keep the demo UI in a new self-contained `frontend/` folder with no build tooling or external dependencies.

**Rationale:** This keeps the sample easy to open, easy to demo, and aligned with the project's lightweight hosted-agent story. The standalone FastAPI `/chat` endpoint now allows cross-origin requests so the static frontend can call `http://localhost:8080/chat` from either `file://` or a local static server.

### Holtzmann Demo Polish (2026-06-13)

**Status:** Approved

Standardize the demo narrative on standalone at port `8080` with `/chat`, and Foundry at port `8088` with `/responses`. Describe the Foundry host exactly as implemented: `LangGraphHostedAgent` adapts the shared graph, `ResponsesHostServer(agent)` exposes it, and the host reads `FOUNDRY_PROJECT_ENDPOINT` plus `AZURE_AI_MODEL_DEPLOYMENT_NAME`.

**Rationale:** The previous script and README drifted from the actual code and could mislead a live demo. Keeping the docs aligned with the implementation preserves the portability story.

### Patty Capabilities Decision (2026-06-13)

**Status:** Approved

The standalone chat history endpoint returns only user and assistant messages from a thread, excluding tool-call and tool-result entries.

**Rationale:** Frontend history consumers need a stable conversational transcript, while LangGraph tool traffic remains implementation detail that would add noise to the UI.

### Patty CI/CD Decision (2026-06-13)

**Status:** Approved

Use one focused workflow on `ubuntu-latest` for pushes and pull requests to `main`, installing from `requirements.txt`, linting with Ruff, and running pytest with `PYTHONPATH=src`.

**Rationale:** This keeps the backend validation path small, fast, and aligned with the existing project layout and dependency source of truth.

### Patty Deployment Decision (2026-06-13)

**Status:** Approved

Use Azure Container Apps as the shared deployment target for both hosting models, and prefer managed identities over embedded secrets.

- Standalone deployment uses a Container App with the FastAPI host on port 8080.
- Foundry deployment provisions a user-assigned managed identity in Bicep, grants Azure OpenAI access through RBAC, and uses that identity for ACR pulls when a registry resource ID is provided.
- Deployment scripts are responsible for wiring the required host-specific environment variables instead of duplicating runtime logic.

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
