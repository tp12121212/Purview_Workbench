import base64
import json

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from db.base import Base
from db.session import get_db
from main import app


def _dev_token(payload: dict[str, object]) -> str:
    raw = json.dumps(payload).encode("utf-8")
    encoded = base64.urlsafe_b64encode(raw).decode("utf-8").rstrip("=")
    return f"dev.{encoded}"


def _client() -> TestClient:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
    Base.metadata.create_all(bind=engine)

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    return TestClient(app)


def _sample_payload() -> dict:
    return {
        "version": "1.0.0",
        "generated": "2026-03-07",
        "patterns": [
            {
                "schema": "testpattern/v1",
                "name": "Sample Regex Pattern",
                "slug": "sample-regex-pattern",
                "version": "1.0.0",
                "type": "regex",
                "engine": "universal",
                "description": "Regex pattern sample",
                "operation": "Match with regex",
                "pattern": "(?i)\\bsecret\\b",
                "confidence": "high",
                "confidence_justification": "well-bounded",
                "jurisdictions": ["au"],
                "regulations": ["gdpr"],
                "data_categories": ["pii"],
                "corroborative_evidence": {"keywords": ["secret"], "proximity": 300},
                "test_cases": {
                    "should_match": [{"description": "positive", "value": "contains secret"}],
                    "should_not_match": [{"description": "negative", "value": "hello world"}],
                },
                "false_positives": [{"description": "fiction", "mitigation": "exclude fiction"}],
                "exports": ["purview_xml", "yaml"],
                "scope": "wide",
                "purview": {
                    "patterns_proximity": 300,
                    "recommended_confidence": 85,
                    "pattern_tiers": [{"tier": "high", "confidence": 85}],
                    "keywords": [{"name": "primary", "words": ["secret", "classified"]}],
                    "regexes": [{"name": "primary_regex", "pattern": "(?i)\\bsecret\\b"}],
                    "filters": [{"type": "exclude", "keywords": ["mock"], "description": "test docs"}],
                    "validators": [{"id": "val1", "type": "checksum", "params": {"mod": 11}}],
                },
                "sensitivity_labels": {"us_gov": "CUI"},
                "references": [{"title": "Ref", "url": "https://example.com"}],
                "created": "2026-01-01",
                "updated": "2026-03-01",
                "author": "tester",
                "source": "custom",
                "license": "MIT",
            },
            {
                "schema": "testpattern/v1",
                "name": "Sample Keyword List",
                "slug": "sample-keyword-list",
                "version": "1.0.0",
                "type": "keyword_list",
                "description": "Keyword pattern",
                "operation": "Keyword match",
                "confidence": "low",
                "confidence_justification": "broad",
                "jurisdictions": ["uk"],
                "regulations": ["uk-gdpr"],
                "data_categories": ["financial"],
                "corroborative_evidence": {"keywords": ["iban"], "proximity": 100},
                "test_cases": {"should_match": [], "should_not_match": []},
                "false_positives": [],
                "exports": ["yaml"],
                "scope": "narrow",
                "purview": {
                    "patterns_proximity": 100,
                    "recommended_confidence": 65,
                    "pattern_tiers": [{"confidence_level": 65, "id_match": "kw1"}],
                    "keywords": [
                        {
                            "id": "kw1",
                            "groups": [{"match_style": "word", "terms": ["iban", "swift"]}],
                        }
                    ],
                    "regexes": [],
                },
                "sensitivity_labels": {},
                "references": [],
                "created": "2026-01-10",
                "updated": "2026-03-02",
                "author": "tester",
                "source": "community",
                "license": "MIT",
            },
        ],
        "collections": [
            {
                "schema": "testpattern/v1",
                "name": "Finance Collection",
                "slug": "finance-collection",
                "description": "Finance",
                "jurisdictions": ["uk"],
                "regulations": ["uk-gdpr"],
                "patterns": ["sample-keyword-list"],
                "created": "2026-01-01",
                "updated": "2026-03-01",
                "author": "tester",
                "license": "MIT",
            }
        ],
        "keywords": [
            {
                "schema": "testpattern/v1",
                "name": "Finance Keywords",
                "slug": "finance-keywords",
                "type": "keyword_list",
                "description": "Finance terms",
                "jurisdictions": ["uk"],
                "data_categories": ["financial"],
                "keywords": ["iban", "swift"],
                "created": "2026-01-01",
                "updated": "2026-03-01",
                "author": "tester",
                "license": "MIT",
            }
        ],
    }


def test_import_and_query_pattern_library() -> None:
    client = _client()
    token = _dev_token({"sub": "user-1", "tenant_id": "tenant-1", "is_admin": True})

    import_response = client.post(
        "/api/v1/patterns/import",
        headers={"Authorization": f"Bearer {token}"},
        json={"payload": _sample_payload()},
    )

    assert import_response.status_code == 200
    assert import_response.json()["imported_patterns"] == 2
    assert import_response.json()["imported_collections"] == 1
    assert import_response.json()["imported_keyword_collections"] == 1

    list_response = client.get("/api/v1/public/patterns")
    assert list_response.status_code == 200
    assert list_response.json()["total"] == 2

    filtered = client.get("/api/v1/public/patterns", params={"type": "keyword_list", "jurisdiction": "uk", "export": "yaml"})
    assert filtered.status_code == 200
    assert filtered.json()["total"] == 1
    assert filtered.json()["items"][0]["slug"] == "sample-keyword-list"

    detail_response = client.get("/api/v1/public/patterns/sample-regex-pattern")
    assert detail_response.status_code == 200
    body = detail_response.json()
    assert body["slug"] == "sample-regex-pattern"
    assert len(body["regexes"]) >= 1
    assert len(body["keyword_groups"]) >= 1
    assert len(body["validators"]) >= 1
    assert len(body["filters"]) >= 1
    assert len(body["pattern_tiers"]) >= 1
    assert len(body["test_cases"]) == 2
    assert len(body["false_positives"]) == 1


def test_import_requires_auth() -> None:
    client = _client()

    response = client.post("/api/v1/patterns/import", json={"payload": _sample_payload()})

    assert response.status_code == 401


def test_import_validation_rejects_invalid_payload() -> None:
    client = _client()
    token = _dev_token({"sub": "user-1", "tenant_id": "tenant-1", "is_admin": True})

    response = client.post(
        "/api/v1/patterns/import",
        headers={"Authorization": f"Bearer {token}"},
        json={"payload": {"patterns": "invalid"}},
    )

    assert response.status_code == 400
    assert "patterns must be an array" in response.json()["detail"]
