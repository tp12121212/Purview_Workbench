from functools import lru_cache
import os

from pydantic import BaseModel, Field


class ApiSettings(BaseModel):
    api_entra_client_id: str = Field(default="")
    api_entra_tenant_mode: str = Field(default="multi-tenant")
    api_allowed_audience: str = Field(default="")
    api_database_url: str = Field(default="sqlite:///./purview_workbench.db")
    api_admin_consent_redirect_uri: str = Field(default="")


@lru_cache
def get_settings() -> ApiSettings:
    return ApiSettings(
        api_entra_client_id=os.getenv("API_ENTRA_CLIENT_ID", ""),
        api_entra_tenant_mode=os.getenv("API_ENTRA_TENANT_MODE", "multi-tenant"),
        api_allowed_audience=os.getenv("API_ALLOWED_AUDIENCE", ""),
        api_database_url=os.getenv("API_DATABASE_URL", "sqlite:///./purview_workbench.db"),
        api_admin_consent_redirect_uri=os.getenv("API_ADMIN_CONSENT_REDIRECT_URI", ""),
    )
