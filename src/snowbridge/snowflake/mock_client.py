from typing import Any
from uuid import uuid4

from snowbridge.models import ConnectionStatus, OperationName, QueryResult
from snowbridge.snowflake.client import InvalidOperationParametersError, SnowflakeClientError


class MockSnowflakeClient:
    def test_connection(self) -> ConnectionStatus:
        return ConnectionStatus(
            connected=True,
            backend="mock",
            detail="Mock Snowflake connection is available.",
        )

    def execute(
        self,
        operation: OperationName,
        parameters: dict[str, Any],
    ) -> QueryResult:
        if parameters.get("simulate_error") is True:
            raise SnowflakeClientError("Simulated Snowflake execution failure.")

        if operation is OperationName.ECHO:
            message = parameters.get("message")
            if not isinstance(message, str) or not message:
                raise InvalidOperationParametersError(
                    "The echo operation requires a non-empty string parameter named 'message'."
                )
            rows = [{"MESSAGE": message}]
        else:
            rows = [
                {
                    "ACCOUNT_NAME": "MOCK_ACCOUNT",
                    "USER_NAME": "SNOWBRIDGE_MOCK_USER",
                    "ROLE_NAME": "SNOWBRIDGE_MOCK_ROLE",
                    "WAREHOUSE_NAME": "SNOWBRIDGE_MOCK_WH",
                }
            ]

        return QueryResult(
            query_id=f"mock-{uuid4()}",
            columns=list(rows[0]),
            rows=rows,
            row_count=len(rows),
        )
