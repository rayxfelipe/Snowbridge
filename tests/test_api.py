from fastapi.testclient import TestClient

from snowbridge.config import Settings
from snowbridge.main import create_app


def build_client() -> TestClient:
    return TestClient(create_app(Settings(snowflake_backend="mock")))


def test_health_reports_mock_backend() -> None:
    response = build_client().get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "healthy", "backend": "mock"}


def test_mock_snowflake_connection_is_available() -> None:
    response = build_client().get("/v1/snowflake/health")

    assert response.status_code == 200
    assert response.json()["connected"] is True
    assert response.json()["backend"] == "mock"


def test_submit_and_retrieve_echo_job() -> None:
    client = build_client()
    submitted = client.post(
        "/v1/jobs",
        json={
            "operation": "echo",
            "parameters": {"message": "hello from Azure"},
            "idempotency_key": "test-echo-1",
        },
    )

    assert submitted.status_code == 201
    job = submitted.json()
    assert job["status"] == "succeeded"
    assert job["result"]["rows"] == [{"MESSAGE": "hello from Azure"}]

    retrieved = client.get(f"/v1/jobs/{job['job_id']}")
    assert retrieved.status_code == 200
    assert retrieved.json() == job


def test_idempotency_key_returns_original_job() -> None:
    client = build_client()
    request = {
        "operation": "echo",
        "parameters": {"message": "only once"},
        "idempotency_key": "same-request",
    }

    first = client.post("/v1/jobs", json=request).json()
    second = client.post("/v1/jobs", json=request).json()

    assert second["job_id"] == first["job_id"]


def test_echo_rejects_missing_message() -> None:
    response = build_client().post(
        "/v1/jobs",
        json={"operation": "echo", "parameters": {}},
    )

    assert response.status_code == 400
    assert "message" in response.json()["detail"]


def test_mock_failure_returns_service_unavailable() -> None:
    response = build_client().post(
        "/v1/jobs",
        json={
            "operation": "current_context",
            "parameters": {"simulate_error": True},
        },
    )

    assert response.status_code == 503
    assert response.json() == {"detail": "Simulated Snowflake execution failure."}
