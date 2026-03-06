from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from auth.token_validation import AuthContext, get_auth_context
from db.session import get_db
from models.tenant import Tenant
from models.tenant_membership import TenantMembership
from models.user import User
from schemas.auth import MeResponse
from schemas.tenant import ConsentCompleteRequest, ConsentStatusResponse, TenantSummaryResponse

router = APIRouter(tags=["auth", "tenants"])


def _ensure_user_and_membership(db: Session, auth: AuthContext) -> tuple[User, Tenant, TenantMembership]:
    user = db.scalar(select(User).where(User.external_user_id == auth.user_external_id))
    if user is None:
        user = User(
            external_user_id=auth.user_external_id,
            email=auth.email,
            display_name=auth.display_name,
        )
        db.add(user)
        db.flush()

    tenant = db.scalar(select(Tenant).where(Tenant.external_tenant_id == auth.tenant_external_id))
    if tenant is None:
        tenant = Tenant(external_tenant_id=auth.tenant_external_id)
        db.add(tenant)
        db.flush()

    membership = db.scalar(
        select(TenantMembership).where(TenantMembership.tenant_id == tenant.id, TenantMembership.user_id == user.id)
    )
    if membership is None:
        membership = TenantMembership(
            tenant_id=tenant.id,
            user_id=user.id,
            role="admin" if auth.is_admin else "member",
        )
        db.add(membership)
        db.flush()

    return user, tenant, membership


@router.get("/me", response_model=MeResponse)
def get_me(auth: AuthContext = Depends(get_auth_context), db: Session = Depends(get_db)) -> MeResponse:
    user, _, _ = _ensure_user_and_membership(db, auth)
    db.commit()
    return MeResponse(
        user_id=user.external_user_id,
        email=user.email,
        display_name=user.display_name,
        tenant_external_id=auth.tenant_external_id,
    )


@router.get("/tenants/me", response_model=TenantSummaryResponse)
def get_my_tenant(auth: AuthContext = Depends(get_auth_context), db: Session = Depends(get_db)) -> TenantSummaryResponse:
    _, tenant, _ = _ensure_user_and_membership(db, auth)
    db.commit()
    return TenantSummaryResponse(
        id=tenant.id,
        external_tenant_id=tenant.external_tenant_id,
        display_name=tenant.display_name,
        consent_completed=tenant.consent_completed,
    )


@router.get("/tenants/me/consent-status", response_model=ConsentStatusResponse)
def get_consent_status(
    auth: AuthContext = Depends(get_auth_context), db: Session = Depends(get_db)
) -> ConsentStatusResponse:
    _, tenant, _ = _ensure_user_and_membership(db, auth)
    db.commit()
    return ConsentStatusResponse(
        tenant_id=tenant.id,
        consent_completed=tenant.consent_completed,
        consent_completed_at=tenant.consent_completed_at,
    )


@router.post("/tenants/consent-complete", response_model=ConsentStatusResponse)
def complete_consent(
    request: ConsentCompleteRequest,
    auth: AuthContext = Depends(get_auth_context),
    db: Session = Depends(get_db),
) -> ConsentStatusResponse:
    if not auth.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="admin role required")

    _, tenant, _ = _ensure_user_and_membership(db, auth)
    tenant.consent_completed = True
    tenant.consent_completed_at = datetime.now(timezone.utc)
    if request.display_name:
        tenant.display_name = request.display_name
    db.commit()
    db.refresh(tenant)
    return ConsentStatusResponse(
        tenant_id=tenant.id,
        consent_completed=tenant.consent_completed,
        consent_completed_at=tenant.consent_completed_at,
    )
