from pydantic import BaseModel


class MeResponse(BaseModel):
    user_id: str
    email: str
    display_name: str
    tenant_external_id: str
