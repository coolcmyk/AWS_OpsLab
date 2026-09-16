from fastapi.testclient import TestClient

from app import app


client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["service"] == "erp-rag-service"


def test_query_requires_approved_document_scope():
    response = client.post("/v1/query", json={
        "question": "What stock is available?",
        "requester_id": "2",
        "allowed_document_ids": [],
        "question_hash": "a" * 64,
    })
    assert response.status_code == 422


def test_query_returns_advisory_and_citation():
    response = client.post("/v1/query", json={
        "question": "Summarize this supplier agreement.",
        "requester_id": "2",
        "allowed_document_ids": [7],
        "question_hash": "a" * 64,
    })
    assert response.status_code == 200
    body = response.json()
    assert body["citations"][0]["document_id"] == 7
    assert "verify" in body["advisory"].lower()
