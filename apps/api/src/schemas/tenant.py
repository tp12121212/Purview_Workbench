from datetime import datetime

from pydantic import BaseModel


class TenantSummaryResponse(BaseModel):
    id: str
    external_tenant_id: str
    display_name: str
    consent_completed: bool


class ConsentStatusResponse(BaseModel):
    tenant_id: str
    consent_completed: bool
    consent_completed_at: datetime | None


class ConsentCompleteRequest(BaseModel):
    display_name: str = ""
