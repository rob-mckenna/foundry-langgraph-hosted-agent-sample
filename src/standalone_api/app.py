import os
from functools import lru_cache
from typing import Any, Literal

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from dotenv import load_dotenv
from fastapi import FastAPI, Query
from langchain_core.messages import AIMessage, BaseMessage, HumanMessage
from langchain_openai import AzureChatOpenAI
from langgraph.checkpoint.memory import MemorySaver
from pydantic import BaseModel, Field

from claims_agent.graph import build_graph

load_dotenv()

app = FastAPI(title="Claims Status Inquiry API", version="0.1.0")


class ChatRequest(BaseModel):
    message: str = Field(min_length=1)
    thread_id: str = Field(min_length=1)


class ChatResponse(BaseModel):
    thread_id: str
    response: str


class ChatHistoryMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str


class ChatHistoryResponse(BaseModel):
    thread_id: str
    messages: list[ChatHistoryMessage]


def build_chat_model() -> AzureChatOpenAI:
    endpoint = os.getenv("AZURE_OPENAI_ENDPOINT", "").strip().rstrip("/")
    deployment = os.getenv("AZURE_OPENAI_DEPLOYMENT", "").strip()
    if not endpoint or not deployment:
        raise RuntimeError(
            "Standalone API requires AZURE_OPENAI_ENDPOINT and AZURE_OPENAI_DEPLOYMENT. Run az login before starting the API."
        )

    credential = DefaultAzureCredential()
    token_provider = get_bearer_token_provider(
        credential,
        "https://ai.azure.com/.default",
    )
    return AzureChatOpenAI(
        azure_deployment=deployment,
        azure_endpoint=endpoint,
        azure_ad_token_provider=token_provider,
        api_version="2024-12-01-preview",
    )


@lru_cache(maxsize=1)
def get_graph():
    checkpointer = MemorySaver()
    return build_graph(model=build_chat_model(), checkpointer=checkpointer)


def _extract_text(content: Any) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, str):
                parts.append(item)
            elif isinstance(item, dict) and isinstance(item.get("text"), str):
                parts.append(item["text"])
            else:
                parts.append(str(item))
        return "\n".join(part for part in parts if part)
    if content is None:
        return ""
    return str(content)


def _extract_response_text(messages: list[BaseMessage]) -> str:
    for message in reversed(messages):
        if isinstance(message, AIMessage):
            text = _extract_text(message.content)
            if text:
                return text
    return ""


def _serialize_chat_history(messages: list[BaseMessage]) -> list[ChatHistoryMessage]:
    history: list[ChatHistoryMessage] = []
    for message in messages:
        if isinstance(message, HumanMessage):
            text = _extract_text(message.content)
            if text:
                history.append(ChatHistoryMessage(role="user", content=text))
        elif isinstance(message, AIMessage):
            text = _extract_text(message.content)
            if text:
                history.append(ChatHistoryMessage(role="assistant", content=text))
    return history


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


@app.get("/chat/history", response_model=ChatHistoryResponse)
def chat_history(thread_id: str = Query(min_length=1)) -> ChatHistoryResponse:
    graph = get_graph()
    state = graph.get_state(config={"configurable": {"thread_id": thread_id}})
    values = getattr(state, "values", {}) if state is not None else {}
    messages = values.get("messages", []) or []
    return ChatHistoryResponse(
        thread_id=thread_id,
        messages=_serialize_chat_history(messages),
    )
