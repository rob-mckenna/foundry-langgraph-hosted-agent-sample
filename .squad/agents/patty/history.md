# Patty — History

## Project Context
- **Project:** foundry-langgraph-hosted-agent-sample
- **User:** Rob McKenna
- **Stack:** Python, LangGraph, Docker, Microsoft Foundry, Azure
- **Purpose:** Demo for health/life sciences payor customer showing LangGraph agent standalone vs. MS Foundry hosted

## Learnings
- Built the shared `src\claims_agent\` package with deterministic claims, member, and benefit tools plus a LangGraph `StateGraph` tool-calling loop.
- Added the standalone FastAPI `/chat` host with `MemorySaver`, the Microsoft Foundry `ResponsesHostServer` host, Docker assets, tests, and supporting deployment files for the demo.

