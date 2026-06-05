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

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
