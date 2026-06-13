# Gozer — History

## Project Context

- **Project:** foundry-langgraph-hosted-agent-sample
- **User:** Rob McKenna
- **Stack:** Python, LangGraph, Docker, Microsoft Foundry, Azure
- **Purpose:** Demo showing a LangGraph agent running standalone in a container, then adapted for MS Foundry hosted agent service. Health/life sciences payor use case (claims processing assistant).
- **API endpoint:** POST /responses with JSON body `{"input": "..."}`
- **Port:** 8080

## Learnings

- Built a self-contained `frontend/` demo with vanilla HTML, CSS, and JavaScript so the claims assistant can be shown without a frontend build step.
- Enabled permissive CORS on the standalone `/chat` API so the static demo works both from `frontend/index.html` and from a lightweight local web server.
