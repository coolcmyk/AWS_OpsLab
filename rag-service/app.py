"""Read-only ERP RAG API with mock and Amazon Bedrock answer providers."""
import os
import time
from uuid import uuid4

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(title="ERP Intelligence RAG Service", version="0.2.0")


class ScopedDocument(BaseModel):
    id: int
    title: str = Field(min_length=1, max_length=512)
    excerpt: str = Field(min_length=1, max_length=4000)


class QueryRequest(BaseModel):
    question: str = Field(min_length=3, max_length=2000)
    requester_id: str = Field(min_length=1)
    allowed_documents: list[ScopedDocument] = Field(default_factory=list, max_length=5)
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


def bedrock_answer(question: str, documents: list[ScopedDocument]) -> tuple[str, str]:
    """Use Bedrock only with the small, authorization-scoped excerpts supplied by Odoo."""
    try:
        import boto3
        from botocore.exceptions import BotoCoreError, ClientError

        model_id = os.getenv("BEDROCK_MODEL_ID", "amazon.nova-lite-v1:0")
        region = os.getenv("BEDROCK_REGION", os.getenv("AWS_REGION", "ap-southeast-1"))
        evidence = "\n\n".join(
            f"[Document {document.id}: {document.title}]\n{document.excerpt}" for document in documents
        )
        response = boto3.client("bedrock-runtime", region_name=region).converse(
            modelId=model_id,
            system=[{
                "text": (
                    "You are a read-only ERP assistant. Answer only from the supplied evidence. "
                    "If the evidence does not answer the question, say that evidence is insufficient. "
                    "Never propose, perform, or imply an ERP write action."
                )
            }],
            messages=[{"role": "user", "content": [{"text": f"Evidence:\n{evidence}\n\nQuestion: {question}"}]}],
            inferenceConfig={"maxTokens": 300, "temperature": 0},
        )
        answer = response["output"]["message"]["content"][0]["text"]
        return answer, model_id
    except (BotoCoreError, ClientError, KeyError, IndexError) as exc:
        raise HTTPException(status_code=503, detail="Bedrock answer generation is unavailable.") from exc


@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "erp-rag-service",
        "provider": os.getenv("AI_PROVIDER", "mock"),
        "model": os.getenv("BEDROCK_MODEL_ID", "deterministic-mvp"),
    }


@app.post("/v1/query", response_model=QueryResponse)
def query(payload: QueryRequest):
    started = time.perf_counter()
    provider = os.getenv("AI_PROVIDER", "mock")
    if not payload.allowed_documents:
        return QueryResponse(
            query_id=str(uuid4()),
            answer="Insufficient evidence: no approved, indexed text documents are available to your account.",
            citations=[],
            provider=provider,
            model="none",
            latency_ms=round((time.perf_counter() - started) * 1000),
            advisory="AI-generated advisory — verify before operational use.",
        )

    if provider == "bedrock":
        answer, model = bedrock_answer(payload.question, payload.allowed_documents)
    else:
        answer = (
            "Mock advisory answer: retrieval found authorized document excerpts. Amazon Bedrock is disabled "
            "for this provider setting; verify the cited source before operational use."
        )
        model = "deterministic-mvp"

    citations = [
        Citation(document_id=document.id, title=document.title, reference="Authorized text excerpt")
        for document in payload.allowed_documents
    ]
    return QueryResponse(
        query_id=str(uuid4()),
        answer=answer,
        citations=citations,
        provider=provider,
        model=model,
        latency_ms=round((time.perf_counter() - started) * 1000),
        advisory="AI-generated advisory — verify before operational use.",
    )
