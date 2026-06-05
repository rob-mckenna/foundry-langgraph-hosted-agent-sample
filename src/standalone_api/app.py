import os
from functools import lru_cache

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
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
    endpoint = os.getenv("AZURE_OPENAI_ENDPOINT", "").strip().rstrip("/")
    deployment = os.getenv("AZURE_OPENAI_DEPLOYMENT", "").strip()
    if not endpoint or not deployment:
        raise RuntimeError(
            "Standalone API requires AZURE_OPENAI_ENDPOINT and AZURE_OPENAI_DEPLOYMENT. Run az login before starting the API."
        )

    credential = DefaultAzureCredential()
    token_provider = get_bearer_token_provider(
        credential,
        "https://cognitiveservices.azure.com/.default",
    )
    return ChatOpenAI(
        model=deployment,
        base_url=f"{endpoint}/openai/deployments/{deployment}",
        api_key=token_provider,
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
