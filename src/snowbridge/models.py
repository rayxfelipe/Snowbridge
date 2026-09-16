from datetime import UTC, datetime
from enum import StrEnum
from typing import Any

from pydantic import BaseModel, Field


class OperationName(StrEnum):
    ECHO = "echo"
    CURRENT_CONTEXT = "current_context"


class JobStatus(StrEnum):
    SUCCEEDED = "succeeded"
    FAILED = "failed"


class HealthResponse(BaseModel):
    status: str
    backend: str


class ConnectionStatus(BaseModel):
    connected: bool
    backend: str
    detail: str


class QueryResult(BaseModel):
    query_id: str
    columns: list[str]
    rows: list[dict[str, Any]]
    row_count: int = Field(ge=0)


class JobRequest(BaseModel):
    operation: OperationName
    parameters: dict[str, Any] = Field(default_factory=dict)
    idempotency_key: str | None = Field(default=None, min_length=1, max_length=128)


class JobResponse(BaseModel):
    job_id: str
    status: JobStatus
    operation: OperationName
    submitted_at: datetime
    completed_at: datetime
    result: QueryResult | None = None
    error: str | None = None

    @classmethod
    def succeeded(
        cls,
        *,
        job_id: str,
        operation: OperationName,
        result: QueryResult,
    ) -> "JobResponse":
        now = datetime.now(UTC)
        return cls(
            job_id=job_id,
            status=JobStatus.SUCCEEDED,
            operation=operation,
            submitted_at=now,
            completed_at=now,
            result=result,
        )
