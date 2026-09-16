"""Read-only ERP RAG API. The MVP provider is deterministic until Bedrock is wired in."""
import os
import time
from uuid import uuid4

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(title="ERP Intelligence RAG Service", version="0.1.0")


class QueryRequest(BaseModel):
    question: str = Field(min_length=3, max_length=2000)
    requester_id: str = Field(min_length=1)
    allowed_document_ids: list[int] = Field(default_factory=list)
    question_hash: str = Field(min_length=64, max_length=64)


class Citation(BaseModel):
    document_id: int | None = None
    title: str
    reference: str


class QueryResponse(BaseModel):
    query_id: str
    answer: str
    citations: list[Citation]
    provider: str
    model: str
    latency_ms: int
    advisory: str


@app.get("/health")
def health():
    return {"status": "ok", "service": "erp-rag-service", "provider": os.getenv("AI_PROVIDER", "mock")}


@app.post("/v1/query", response_model=QueryResponse)
def query(payload: QueryRequest):
    if not payload.allowed_document_ids:
        raise HTTPException(status_code=422, detail="No approved documents are available to this user.")

    started = time.perf_counter()
    document_id = payload.allowed_document_ids[0]
    return QueryResponse(
        query_id=str(uuid4()),
        answer=(
            "Mock advisory answer: approved documents are available, but Amazon Bedrock and pgvector "
            "retrieval have not been enabled in this local development milestone. Verify against the cited source."
        ),
        citations=[Citation(document_id=document_id, title="Approved Odoo attachment", reference="Mock retrieval chunk 1")],
        provider=os.getenv("AI_PROVIDER", "mock"),
        model="deterministic-mvp",
        latency_ms=round((time.perf_counter() - started) * 1000),
        advisory="AI-generated advisory — verify before operational use.",
    )
