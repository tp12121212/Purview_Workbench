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


def test_get_me_creates_phase1_user_and_membership() -> None:
    client = _client()
    token = _dev_token(
        {
            "sub": "user-1",
            "email": "user@example.com",
            "name": "Example User",
            "tenant_id": "entra-tenant-1",
            "is_admin": True,
        }
    )

    response = client.get("/api/v1/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 200
    assert response.json() == {
        "user_id": "user-1",
        "email": "user@example.com",
        "display_name": "Example User",
        "tenant_external_id": "entra-tenant-1",
    }


def test_get_tenant_and_consent_flow() -> None:
    client = _client()
    token = _dev_token(
        {
            "sub": "user-1",
            "email": "admin@example.com",
            "name": "Tenant Admin",
            "tenant_id": "entra-tenant-2",
            "is_admin": True,
        }
    )
    headers = {"Authorization": f"Bearer {token}"}

    tenant_response = client.get("/api/v1/tenants/me", headers=headers)
    assert tenant_response.status_code == 200
    assert tenant_response.json()["consent_completed"] is False

    status_before = client.get("/api/v1/tenants/me/consent-status", headers=headers)
    assert status_before.status_code == 200
    assert status_before.json()["consent_completed"] is False

    complete = client.post(
        "/api/v1/tenants/consent-complete",
        headers=headers,
        json={"display_name": "Contoso"},
    )
    assert complete.status_code == 200
    assert complete.json()["consent_completed"] is True
    assert complete.json()["consent_completed_at"] is not None


def test_consent_complete_requires_admin() -> None:
    client = _client()
    token = _dev_token(
        {
            "sub": "user-2",
            "tenant_id": "entra-tenant-2",
            "is_admin": False,
        }
    )

    response = client.post(
        "/api/v1/tenants/consent-complete",
        headers={"Authorization": f"Bearer {token}"},
        json={"display_name": "Nope"},
    )

    assert response.status_code == 403
