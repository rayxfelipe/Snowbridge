import logging
from pathlib import Path

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.responses import FileResponse, JSONResponse

from snowbridge.ai.catalog import OPERATION_CATALOG, validate_plan
from snowbridge.ai.client import AiPlannerError
from snowbridge.ai.factory import create_ai_planner
from snowbridge.config import Settings, get_settings
from snowbridge.jobs import JobStore
from snowbridge.models import (
    AiExecuteRequest,
    AiPlanRequest,
    AiPlanResponse,
    ConnectionStatus,
    HealthResponse,
    JobRequest,
    JobResponse,
    PlanStatus,
)
from snowbridge.snowflake.client import (
    InvalidOperationParametersError,
    SnowflakeClientError,
)
from snowbridge.snowflake.factory import create_snowflake_client

logger = logging.getLogger(__name__)
UI_PATH = Path(__file__).parent / "static" / "index.html"


def create_app(settings: Settings | None = None) -> FastAPI:
    app_settings = settings or get_settings()
    app = FastAPI(
        title=app_settings.app_name,
        version="0.1.0",
        description="A governed bridge between Azure orchestrators and Snowflake.",
    )
    app.state.settings = app_settings
    app.state.snowflake_client = create_snowflake_client(app_settings)
    app.state.ai_planner = create_ai_planner(app_settings)
    app.state.job_store = JobStore()

    @app.get("/", include_in_schema=False)
    def business_ui() -> FileResponse:
        return FileResponse(UI_PATH)

    @app.exception_handler(InvalidOperationParametersError)
    async def invalid_parameters_handler(
        request: Request,
        exc: InvalidOperationParametersError,
    ) -> JSONResponse:
        return JSONResponse(status_code=status.HTTP_400_BAD_REQUEST, content={"detail": str(exc)})

    @app.exception_handler(SnowflakeClientError)
    async def snowflake_error_handler(
        request: Request,
        exc: SnowflakeClientError,
    ) -> JSONResponse:
        logger.warning("Snowflake backend request failed", exc_info=exc)
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"detail": str(exc)},
        )

    @app.exception_handler(AiPlannerError)
    async def ai_planner_error_handler(request: Request, exc: AiPlannerError) -> JSONResponse:
        logger.warning("AI planner request failed", exc_info=exc)
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"detail": str(exc)},
        )

    @app.get("/health", response_model=HealthResponse, tags=["health"])
    def health() -> HealthResponse:
        return HealthResponse(status="healthy", backend=app_settings.snowflake_backend)

    @app.get("/v1/snowflake/health", response_model=ConnectionStatus, tags=["snowflake"])
    def snowflake_health() -> ConnectionStatus:
        return app.state.snowflake_client.test_connection()

    @app.get("/v1/ai/operations", tags=["ai"])
    def list_ai_operations() -> list[dict[str, object]]:
        return OPERATION_CATALOG

    @app.post("/v1/ai/plan", response_model=AiPlanResponse, tags=["ai"])
    def plan_operation(request: AiPlanRequest) -> AiPlanResponse:
        return app.state.ai_planner.plan(request.request)

    @app.post(
        "/v1/ai/execute",
        response_model=JobResponse,
        status_code=status.HTTP_201_CREATED,
        tags=["ai"],
    )
    def execute_plan(request: AiExecuteRequest) -> JobResponse:
        if not request.confirmed:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Set confirmed to true before executing an AI-generated plan.",
            )
        if request.plan.status is not PlanStatus.READY:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Only a ready plan can be executed.",
            )
        try:
            plan = validate_plan(request.plan)
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
        assert plan.operation is not None
        job_request = JobRequest(
            operation=plan.operation,
            parameters=plan.parameters,
            idempotency_key=request.idempotency_key,
        )
        return app.state.job_store.submit(job_request, app.state.snowflake_client)

    @app.post(
        "/v1/jobs",
        response_model=JobResponse,
        status_code=status.HTTP_201_CREATED,
        tags=["jobs"],
    )
    def submit_job(request: JobRequest) -> JobResponse:
        return app.state.job_store.submit(request, app.state.snowflake_client)

    @app.get("/v1/jobs/{job_id}", response_model=JobResponse, tags=["jobs"])
    def get_job(job_id: str) -> JobResponse:
        job = app.state.job_store.get(job_id)
        if job is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found.")
        return job

    return app


app = create_app()
