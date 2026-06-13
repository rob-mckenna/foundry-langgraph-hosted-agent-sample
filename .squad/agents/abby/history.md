# Abby — History

## Project Context
- **Project:** foundry-langgraph-hosted-agent-sample
- **User:** Rob McKenna
- **Stack:** Python, LangGraph, Docker, Microsoft Foundry, Azure
- **Purpose:** Demo for health/life sciences payor customer showing LangGraph agent standalone vs. MS Foundry hosted

## Learnings

- 2026-06-13T02:59:26.434-04:00: Added pytest coverage for member-claim search and prior-authorization tools plus end-to-end `/chat/history` API behavior using a deterministic LangGraph checkpointer-backed test graph.

- 2026-06-05T04:30:16.302-04:00: Drafted proactive pytest coverage for mock payor tools, shared graph behavior, the standalone FastAPI `/chat` endpoint, and Foundry host wiring/env-var validation, plus shared mock-LLM and graph fixtures in `tests\conftest.py`.

