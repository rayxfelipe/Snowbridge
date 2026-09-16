# Snowbridge

Snowbridge is a Python HTTP service that gives Azure Data Factory, Microsoft
Fabric, Logic Apps, and other orchestrators one stable interface for controlled
Snowflake operations.

The first version runs against an in-process mock Snowflake adapter. The same API
can later use the official Snowflake Python Connector by changing configuration.

## Current API

- `GET /health`: application health and selected backend.
- `GET /v1/snowflake/health`: adapter connectivity check.
- `POST /v1/jobs`: execute an approved operation.
- `GET /v1/jobs/{job_id}`: retrieve an in-memory job result.
- `GET /docs`: interactive OpenAPI documentation.

The MVP supports two allowlisted operations:

- `echo`: verifies parameter binding and result serialization.
- `current_context`: returns account, user, role, and warehouse context.

Jobs execute synchronously in this first slice but use a job-shaped contract so
queue-backed asynchronous execution can be added without changing callers.

## Local Development

Prerequisites: Python 3.11 through 3.14 and [uv](https://docs.astral.sh/uv/).

```powershell
Copy-Item .env.example .env
uv sync --extra dev
uv run uvicorn snowbridge.main:app --reload
```

Open <http://127.0.0.1:8000/docs> to exercise the API.

Submit a mock operation:

```powershell
$body = @{
	operation = "echo"
	parameters = @{ message = "hello from Azure" }
	idempotency_key = "demo-001"
} | ConvertTo-Json

Invoke-RestMethod `
	-Method Post `
	-Uri http://127.0.0.1:8000/v1/jobs `
	-ContentType application/json `
	-Body $body
```

Run checks:

```powershell
uv run --extra dev pytest
uv run --extra dev ruff check .
```

## Docker

```powershell
docker build -t snowbridge:local .
docker run --rm -p 8000:8000 snowbridge:local
```

On networks that require an approved Python package mirror, pass it at build
time:

```powershell
docker build `
	--build-arg PIP_INDEX_URL=https://your-package-mirror.example/simple/ `
	-t snowbridge:local .
```

The container runs in mock mode by default and does not require Snowflake
credentials.

Build an image containing the optional Snowflake connector when real-account
testing begins:

```powershell
docker build `
	--build-arg 'SNOWBRIDGE_EXTRAS=[snowflake]' `
	-t snowbridge:snowflake .
```

## Switching to a Snowflake Trial Account

Install the optional connector dependency:

```powershell
uv sync --extra dev --extra snowflake
```

Set the backend and connection settings shown in `.env.example`:

```dotenv
SNOWBRIDGE_SNOWFLAKE_BACKEND=snowflake
SNOWBRIDGE_SNOWFLAKE_ACCOUNT=organization-account
SNOWBRIDGE_SNOWFLAKE_USER=SNOWBRIDGE_USER
SNOWBRIDGE_SNOWFLAKE_PRIVATE_KEY_PATH=C:\path\to\snowflake_key.p8
SNOWBRIDGE_SNOWFLAKE_WAREHOUSE=SNOWBRIDGE_WH
SNOWBRIDGE_SNOWFLAKE_DATABASE=SNOWBRIDGE_DB
SNOWBRIDGE_SNOWFLAKE_SCHEMA=PUBLIC
SNOWBRIDGE_SNOWFLAKE_ROLE=SNOWBRIDGE_ROLE
```

Prefer key-pair authentication and a dedicated least-privilege Snowflake role.
Do not commit `.env` or private keys. In Azure, retrieve secrets from Key Vault
using managed identity or mount them as Container Apps secrets.

The public endpoints and request/response formats remain unchanged when the
backend changes.

## Project Structure

```text
src/snowbridge/
|-- config.py
|-- jobs.py
|-- main.py
|-- models.py
`-- snowflake/
	|-- client.py
	|-- factory.py
	|-- mock_client.py
	`-- real_client.py
```

The API depends on the `SnowflakeClient` protocol. Both adapters normalize their
results into the same application models, which keeps Azure callers independent
of Snowflake connector details.