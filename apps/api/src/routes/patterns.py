from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from auth.token_validation import AuthContext, get_auth_context
from db.session import get_db
from schemas.patterns import PatternImportRequest, PatternImportResponse
from services.pattern_service import PatternValidationError, import_pattern_payload, load_import_payload

router = APIRouter(prefix="/patterns", tags=["patterns"])


@router.post("/import", response_model=PatternImportResponse)
def import_patterns(
    request: PatternImportRequest,
    _: AuthContext = Depends(get_auth_context),
    db: Session = Depends(get_db),
) -> PatternImportResponse:
    try:
        payload = load_import_payload(request.payload, request.file_path)
        imported_patterns, imported_collections, imported_keyword_collections, warnings = import_pattern_payload(db, payload)
    except (PatternValidationError, FileNotFoundError, OSError, ValueError) as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    return PatternImportResponse(
        imported_patterns=imported_patterns,
        imported_collections=imported_collections,
        imported_keyword_collections=imported_keyword_collections,
        warnings=warnings,
    )
