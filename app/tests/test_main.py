import os
os.environ["DATABASE_URL"] = "sqlite:///./test_secureai.db"

from fastapi.testclient import TestClient
from main import app


def test_health():
    with TestClient(app) as client:
        response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_create_and_get_incident():
    payload = {
        "source_finding_id": "test-finding-001",
        "title": "Simulated public S3 bucket",
        "description": "Sample only",
        "severity": "high",
        "is_simulated": True,
    }
    with TestClient(app) as client:
        created = client.post("/api/incidents", json=payload)
        assert created.status_code == 201
        incident_id = created.json()["id"]
        fetched = client.get(f"/api/incidents/{incident_id}")
    assert fetched.status_code == 200
    assert fetched.json()["is_simulated"] is True
