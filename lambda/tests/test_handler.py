import pytest
from handler import _finding


def test_normalizes_sample_event():
    finding = _finding({"source": "secureai.demo", "detail": {"id": "a", "severity": "HIGH", "title": "Sample"}})
    assert finding["id"] == "a"
    assert finding["severity"] == "high"
    assert finding["is_simulated"] is True


def test_rejects_missing_id():
    with pytest.raises(ValueError):
        _finding({"detail": {}})
