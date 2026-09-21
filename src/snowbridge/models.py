from datetime import UTC, datetime
from enum import StrEnum
from typing import Any

from pydantic import BaseModel, Field


class OperationName(StrEnum):
    ECHO = "echo"
    CURRENT_CONTEXT = "current_context"
    WAREHOUSE_USAGE_SUMMARY = "warehouse_usage_summary"


class JobStatus(StrEnum):
    SUCCEEDED = "succeeded"
    FAILED = "failed"


class PlanStatus(StrEnum):
    READY = "ready"
    NEEDS_CLARIFICATION = "needs_clarification"
    REJECTED = "rejected"


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


class AiPlanRequest(BaseModel):
    request: str = Field(min_length=3, max_length=2000)


class AiPlanResponse(BaseModel):
    status: PlanStatus
    operation: OperationName | None = None
    parameters: dict[str, Any] = Field(default_factory=dict)
    explanation: str = Field(min_length=1, max_length=500)
    clarification_question: str | None = Field(default=None, max_length=500)


class AiExecuteRequest(BaseModel):
    plan: AiPlanResponse
    confirmed: bool = False
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
