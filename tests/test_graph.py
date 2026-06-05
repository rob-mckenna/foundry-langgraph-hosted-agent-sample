from langchain_core.messages import AIMessage, HumanMessage, ToolMessage

from claims_agent.graph import build_graph


class DummyToolCallingModel:
    def bind_tools(self, tools):
        self.tools = tools
        return self

    def invoke(self, messages):
        last_message = messages[-1]
        if isinstance(last_message, HumanMessage):
            return AIMessage(
                content="",
                tool_calls=[
                    {
                        "id": "call-1",
                        "name": "lookup_claim_status",
                        "args": {"claim_id": "CLM-1001"},
                        "type": "tool_call",
                    }
                ],
            )
        if isinstance(last_message, ToolMessage):
            return AIMessage(content=f"Claim status response: {last_message.content}")
        raise AssertionError(f"Unexpected message type: {type(last_message)!r}")


def test_build_graph_executes_tool_loop() -> None:
    graph = build_graph(model=DummyToolCallingModel())
    result = graph.invoke({"messages": [HumanMessage(content="What is the status of claim CLM-1001?")]})
    final_message = result["messages"][-1]
    assert isinstance(final_message, AIMessage)
    assert "CLM-1001" in final_message.content
    assert "approved" in final_message.content
