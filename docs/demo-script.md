# Demo Script

1. Open `src/claims_agent/graph.py` and explain that the LangGraph workflow, tools, and prompt are shared.
2. Open `src/standalone_api/app.py` and show the `/chat` endpoint plus `MemorySaver` continuity.
3. Run the standalone API locally or through Docker Compose and send a sample claim status request.
4. Open `src/foundry_host/app.py` and compare the small set of changes: Foundry auth, project client, and `ResponsesHostServer`.
5. Show `deployment/foundry/agent.manifest.yaml` to highlight the deployment-specific assets.
6. Conclude with the message: same claims inquiry graph, same tools, different hosting surface.
