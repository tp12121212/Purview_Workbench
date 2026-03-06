import json


def to_worker_json(payload: dict) -> str:
    """Deterministic JSON serialization skeleton for later job outputs."""
    return json.dumps(payload, sort_keys=True, separators=(",", ":"))
