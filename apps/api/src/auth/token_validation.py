def validate_bearer_token_skeleton(token: str) -> dict[str, str]:
    """Phase 0 auth skeleton; real JWT validation added in later phases."""
    if not token:
        return {"status": "missing"}
    return {"status": "placeholder"}
