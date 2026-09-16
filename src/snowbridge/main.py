import logging

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.responses import JSONResponse

from snowbridge.config import Settings, get_settings
from snowbridge.jobs import JobStore
from snowbridge.models import ConnectionStatus, HealthResponse, JobRequest, JobResponse
from snowbridge.snowflake.client import (
    InvalidOperationParametersError,
    SnowflakeClientError,
)
from snowbridge.snowflake.factory import create_snowflake_client

logger = logging.getLogger(__name__)


def create_app(settings: Settings | None = None) -> FastAPI:
    app_settings = settings or get_settings()
    app = FastAPI(
        title=app_settings.app_name,
        version="0.1.0",
        description="A governed bridge between Azure orchestrators and Snowflake.",
    )
    app.state.settings = app_settings
    app.state.snowflake_client = create_snowflake_client(app_settings)
    app.state.job_store = JobStore()

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

    @app.get("/health", response_model=HealthResponse, tags=["health"])
    def health() -> HealthResponse:
        return HealthResponse(status="healthy", backend=app_settings.snowflake_backend)

    @app.get("/v1/snowflake/health", response_model=ConnectionStatus, tags=["snowflake"])
    def snowflake_health() -> ConnectionStatus:
        return app.state.snowflake_client.test_connection()

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
