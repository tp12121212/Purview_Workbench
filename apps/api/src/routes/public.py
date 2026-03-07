from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from db.session import get_db
from schemas.patterns import PatternDetailResponse, PatternListResponse
from services.pattern_service import get_pattern_by_slug, list_patterns, serialize_pattern_detail, serialize_pattern_summary

router = APIRouter(prefix="/public", tags=["public"])


@router.get("/metadata")
def get_public_metadata() -> dict[str, str]:
    return {
        "productName": "Purview Workbench",
        "docsUrl": "/docs",
        "supportEmail": "support@example.com",
    }


@router.get("/library/sit")
def get_public_sit_library() -> list[dict[str, str]]:
    return [
        {
            "id": "sit-1",
            "title": "Payment Card Number detector",
            "summary": "Starter sensitive info type for payment card numbers.",
            "category": "SIT",
        }
    ]


@router.get("/library/dlp")
def get_public_dlp_library() -> list[dict[str, str]]:
    return [
        {
            "id": "dlp-1",
            "title": "PII baseline policy",
            "summary": "Starter DLP policy template for common PII handling.",
            "category": "DLP",
        }
    ]


@router.get("/patterns", response_model=PatternListResponse)
def get_public_patterns(
    q: str | None = None,
    pattern_type: str | None = Query(default=None, alias="type"),
    jurisdiction: str | None = None,
    regulation: str | None = None,
    category: str | None = None,
    risk_min: int | None = Query(default=None, ge=0),
    risk_max: int | None = Query(default=None, ge=0),
    engine: str | None = None,
    scope: str | None = None,
    export: str | None = None,
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> PatternListResponse:
    total, items = list_patterns(
        db,
        query=q,
        pattern_type=pattern_type,
        jurisdiction=jurisdiction,
        regulation=regulation,
        category=category,
        risk_min=risk_min,
        risk_max=risk_max,
        engine=engine,
        scope=scope,
        export_format=export,
        limit=limit,
        offset=offset,
    )
    return PatternListResponse(total=total, items=[serialize_pattern_summary(item) for item in items])


@router.get("/patterns/{slug}", response_model=PatternDetailResponse)
def get_public_pattern_detail(slug: str, db: Session = Depends(get_db)) -> PatternDetailResponse:
    pattern = get_pattern_by_slug(db, slug)
    if pattern is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="pattern not found")
    return PatternDetailResponse.model_validate(serialize_pattern_detail(pattern))
