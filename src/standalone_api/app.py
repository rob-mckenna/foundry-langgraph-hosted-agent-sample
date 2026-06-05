import os
from functools import lru_cache

from fastapi import FastAPI
from langchain_core.messages import AIMessage, HumanMessage
from langchain_openai import ChatOpenAI
from langgraph.checkpoint.memory import MemorySaver
from pydantic import BaseModel, Field

from claims_agent.graph import build_graph

app = FastAPI(title="Claims Status Inquiry API", version="0.1.0")


class ChatRequest(BaseModel):
    message: str = Field(min_length=1)
    thread_id: str = Field(min_length=1)


class ChatResponse(BaseModel):
    thread_id: str
    response: str


def build_chat_model() -> ChatOpenAI:
    azure_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT", "").strip()
    azure_api_key = os.getenv("AZURE_OPENAI_API_KEY", "").strip()
    azure_deployment = os.getenv("AZURE_OPENAI_DEPLOYMENT", "").strip()
    if azure_endpoint and azure_api_key and azure_deployment:
        return ChatOpenAI(
            model=azure_deployment,
            api_key=azure_api_key,
            base_url=f"{azure_endpoint.rstrip('/')}/openai/v1/",
        )

    openai_api_key = os.getenv("OPENAI_API_KEY", "").strip()
    if openai_api_key:
        return ChatOpenAI(
            model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
            api_key=openai_api_key,
        )

    raise RuntimeError(
        "Standalone API requires OPENAI_API_KEY or the Azure OpenAI environment variables."
    )


@lru_cache(maxsize=1)
def get_graph():
    checkpointer = MemorySaver()
    return build_graph(model=build_chat_model(), checkpointer=checkpointer)


def _extract_response_text(messages: list) -> str:
    for message in reversed(messages):
        if isinstance(message, AIMessage) and message.content:
            if isinstance(message.content, str):
                return message.content
            return str(message.content)
    return ""


@app.post("/chat", response_model=ChatResponse)
def chat(request: ChatRequest) -> ChatResponse:
    graph = get_graph()
    result = graph.invoke(
        {"messages": [HumanMessage(content=request.message)]},
        config={"configurable": {"thread_id": request.thread_id}},
    )
    return ChatResponse(
        thread_id=request.thread_id,
        response=_extract_response_text(result["messages"]),
    )
