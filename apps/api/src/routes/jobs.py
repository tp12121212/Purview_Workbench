from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from services.job_service import JobService

router = APIRouter()
service = JobService()


class JobCreateRequest(BaseModel):
    tenant_id: str
    job_type: str
    access_token: str
    payload: dict = {}


@router.post("")
def enqueue_job(request: JobCreateRequest) -> dict[str, str]:
    job_id = service.enqueue(
        tenant_id=request.tenant_id,
        job_type=request.job_type,
        access_token=request.access_token,
        payload=request.payload,
    )
    return {"jobId": job_id, "status": "QUEUED"}


@router.get("/{job_id}")
def get_job(job_id: str) -> dict:
    result = service.get(job_id)
    if result is None:
        raise HTTPException(status_code=404, detail="job not found")
    return result
