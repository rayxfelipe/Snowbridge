from threading import Lock
from uuid import uuid4

from snowbridge.models import JobRequest, JobResponse
from snowbridge.snowflake.client import SnowflakeClient


class JobStore:
    def __init__(self) -> None:
        self._jobs: dict[str, JobResponse] = {}
        self._idempotency_keys: dict[str, str] = {}
        self._lock = Lock()

    def submit(self, request: JobRequest, client: SnowflakeClient) -> JobResponse:
        with self._lock:
            if request.idempotency_key:
                existing_job_id = self._idempotency_keys.get(request.idempotency_key)
                if existing_job_id:
                    return self._jobs[existing_job_id]

            job_id = str(uuid4())
            result = client.execute(request.operation, request.parameters)
            job = JobResponse.succeeded(
                job_id=job_id,
                operation=request.operation,
                result=result,
            )
            self._jobs[job_id] = job
            if request.idempotency_key:
                self._idempotency_keys[request.idempotency_key] = job_id
            return job

    def get(self, job_id: str) -> JobResponse | None:
        with self._lock:
            return self._jobs.get(job_id)
