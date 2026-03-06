from dataclasses import dataclass, field
from uuid import uuid4


@dataclass
class JobRecord:
    job_id: str
    tenant_id: str
    job_type: str
    requested_by: str
    status: str = "QUEUED"
    payload: dict = field(default_factory=dict)


class JobService:
    """Phase 2 in-memory protected job placeholder."""

    def __init__(self) -> None:
        self._jobs: dict[str, JobRecord] = {}

    def enqueue(self, tenant_id: str, job_type: str, payload: dict, requested_by: str) -> str:
        job_id = str(uuid4())
        self._jobs[job_id] = JobRecord(
            job_id=job_id,
            tenant_id=tenant_id,
            job_type=job_type,
            payload=payload,
            requested_by=requested_by,
        )
        return job_id

    def get(self, job_id: str) -> dict | None:
        job = self._jobs.get(job_id)
        if job is None:
            return None
        return {
            "jobId": job.job_id,
            "tenantId": job.tenant_id,
            "jobType": job.job_type,
            "status": job.status,
            "result": None,
            "requestedBy": job.requested_by,
        }
