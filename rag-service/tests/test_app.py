from fastapi.testclient import TestClient

from app import app


client = TestClient(app)


def payload(documents):
    return {
        "question": "What do the approved terms say?",
        "requester_id": "2",
        "allowed_documents": documents,
        "question_hash": "a" * 64,
    }


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["service"] == "erp-rag-service"


def test_query_without_authorized_evidence_is_safe():
    response = client.post("/v1/query", json=payload([]))
    assert response.status_code == 200
    assert "insufficient evidence" in response.json()["answer"].lower()


def test_query_returns_advisory_and_citation():
    response = client.post("/v1/query", json=payload([{
        "id": 7,
        "title": "Synthetic supplier terms",
        "excerpt": "Payment is due within 30 days.",
    }]))
    assert response.status_code == 200
    body = response.json()
    assert body["citations"][0]["document_id"] == 7
    assert "verify" in body["advisory"].lower()
