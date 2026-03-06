def validate_tenant_match(token_tid: str, tenant_id: str) -> bool:
    """Phase 0 placeholder for tid-to-tenant enforcement."""
    return bool(token_tid and tenant_id and token_tid == tenant_id)
