from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from auth.token_validation import AuthContext, get_auth_context
from services.job_service import JobService

router = APIRouter(tags=["jobs"])
service = JobService()


class TestTextExtractionJobRequest(BaseModel):
    tenant_id: str
    file_name: str = Field(min_length=1)
    text_sample: str = Field(min_length=1)


class TestDataClassificationJobRequest(BaseModel):
    tenant_id: str
    text_sample: str = Field(min_length=1)
    expected_labels: list[str]


@router.post("/test-text-extraction")
def enqueue_test_text_extraction(
    request: TestTextExtractionJobRequest,
    auth: AuthContext = Depends(get_auth_context),
) -> dict[str, str]:
    job_id = service.enqueue(
        tenant_id=request.tenant_id,
        job_type="TEST_TEXT_EXTRACTION",
        payload={"file_name": request.file_name, "text_sample": request.text_sample},
        requested_by=auth.user_external_id,
    )
    return {"jobId": job_id, "status": "QUEUED", "jobType": "TEST_TEXT_EXTRACTION"}


@router.post("/test-data-classification")
def enqueue_test_data_classification(
    request: TestDataClassificationJobRequest,
    auth: AuthContext = Depends(get_auth_context),
) -> dict[str, str]:
    job_id = service.enqueue(
        tenant_id=request.tenant_id,
        job_type="TEST_DATA_CLASSIFICATION",
        payload={"text_sample": request.text_sample, "expected_labels": request.expected_labels},
        requested_by=auth.user_external_id,
    )
    return {"jobId": job_id, "status": "QUEUED", "jobType": "TEST_DATA_CLASSIFICATION"}


@router.get("/{job_id}")
def get_job(job_id: str, auth: AuthContext = Depends(get_auth_context)) -> dict:
    result = service.get(job_id)
    if result is None:
        raise HTTPException(status_code=404, detail="job not found")
    if result["requestedBy"] != auth.user_external_id:
        raise HTTPException(status_code=404, detail="job not found")
    return result
