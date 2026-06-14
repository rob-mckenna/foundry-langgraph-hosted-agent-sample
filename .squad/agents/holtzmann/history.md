# Holtzmann — History

## Project Context
- **Project:** foundry-langgraph-hosted-agent-sample
- **User:** Rob McKenna
- **Stack:** Python, LangGraph, Docker, Microsoft Foundry, Azure
- **Purpose:** Demo for health/life sciences payor customer showing LangGraph agent standalone vs. MS Foundry hosted

## Learnings

- 2026-06-13T03:17:13: Demo story complete—Gozer frontend now live, standalone at port 8080, Foundry at port 8088. Chat history API available; full CI/CD and deployment automation deployed.

- Polished `docs/demo-script.md` and `README.md` to match the live code paths, ports, endpoints, and environment variables; the Foundry host story should be presented as `LangGraphHostedAgent` plus `ResponsesHostServer(agent)` on port `8088`.

- 2026-06-14T00:27:00-04:00: README rewritten to document THREE deployment modes: Standalone (`standalone_api/app.py`, port 8080), ACA-Hosted (`aca_hosted/app.py`, port 8088), and Foundry Hosted Agent (same `aca_hosted/app.py` image, registered via `agent.yaml`). The old README referenced `foundry_host/app.py` which no longer exists—correct path is `aca_hosted/app.py`. Key architectural truth: `claims_agent/graph.py` is IDENTICAL across all three modes; the only new code to migrate standalone→ACA-Hosted is the `LangGraphHostedAgent` adapter (~60 lines) plus `ResponsesHostServer` wrapper. ACA-Hosted→Foundry Hosted Agent requires zero code changes—same Dockerfile, same entry point. `azure.yaml` defines all three services: `claims-standalone-agent`, `claims-aca-agent`, `claims-foundry-agent`. `azd up` deploys all three.
