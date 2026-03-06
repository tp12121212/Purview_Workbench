import base64
import json
from dataclasses import dataclass

from fastapi import Header, HTTPException, status


@dataclass
class AuthContext:
    user_external_id: str
    email: str
    display_name: str
    tenant_external_id: str
    is_admin: bool


def _decode_dev_token_payload(token: str) -> dict[str, object]:
    if not token.startswith("dev."):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="unsupported token format")

    encoded_payload = token.removeprefix("dev.")
    padding = "=" * (-len(encoded_payload) % 4)
    try:
        raw_json = base64.urlsafe_b64decode(f"{encoded_payload}{padding}").decode("utf-8")
        return json.loads(raw_json)
    except (ValueError, json.JSONDecodeError) as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid token payload") from exc


def _extract_bearer_token(authorization: str | None) -> str:
    if authorization is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="missing authorization header")
    scheme, _, value = authorization.partition(" ")
    if scheme.lower() != "bearer" or not value:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid bearer token")
    return value


def get_auth_context(authorization: str | None = Header(default=None)) -> AuthContext:
    token = _extract_bearer_token(authorization)
    payload = _decode_dev_token_payload(token)

    required_claims = ["sub", "tenant_id"]
    for claim in required_claims:
        if claim not in payload:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"missing claim: {claim}")

    return AuthContext(
        user_external_id=str(payload["sub"]),
        email=str(payload.get("email", "")),
        display_name=str(payload.get("name", "")),
        tenant_external_id=str(payload["tenant_id"]),
        is_admin=bool(payload.get("is_admin", False)),
    )
