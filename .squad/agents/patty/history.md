# Patty — History

## Project Context
- **Project:** foundry-langgraph-hosted-agent-sample
- **User:** Rob McKenna
- **Stack:** Python, LangGraph, Docker, Microsoft Foundry, Azure
- **Purpose:** Demo for health/life sciences payor customer showing LangGraph agent standalone vs. MS Foundry hosted

## Learnings
- Built the shared `src\claims_agent\` package with deterministic claims, member, and benefit tools plus a LangGraph `StateGraph` tool-calling loop.
- Added the standalone FastAPI `/chat` host with `MemorySaver`, the Microsoft Foundry `ResponsesHostServer` host, Docker assets, tests, and supporting deployment files for the demo.
- 2026-06-13T02:44:48-04:00: Expanded the shared claims package with member claim search and prior authorization status tools backed by deterministic sample data.
- 2026-06-13T02:44:48-04:00: Added standalone chat history retrieval that rehydrates a thread from LangGraph memory and returns only user/assistant messages for frontend rendering.
- 2026-06-13T02:44:48-04:00: Added Azure deployment automation for both hosting models with Container Apps scripts, Foundry azd/Bicep provisioning, managed identity, and RBAC.
