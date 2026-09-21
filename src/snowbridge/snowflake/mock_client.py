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
        elif operation is OperationName.CURRENT_CONTEXT:
            rows = [
                {
                    "ACCOUNT_NAME": "MOCK_ACCOUNT",
                    "USER_NAME": "SNOWBRIDGE_MOCK_USER",
                    "ROLE_NAME": "SNOWBRIDGE_MOCK_ROLE",
                    "WAREHOUSE_NAME": "SNOWBRIDGE_MOCK_WH",
                }
            ]
        else:
            days = parameters.get("days")
            if isinstance(days, bool) or not isinstance(days, int) or not 1 <= days <= 90:
                raise InvalidOperationParametersError(
                    "Warehouse usage requires an integer days value from 1 through 90."
                )
            rows = [
                {
                    "WAREHOUSE_NAME": "SNOWBRIDGE_MOCK_WH",
                    "CREDITS_USED": round(days * 0.42, 2),
                    "EXECUTION_HOURS": round(days * 1.75, 2),
                    "PERIOD_DAYS": days,
                },
                {
                    "WAREHOUSE_NAME": "ANALYTICS_MOCK_WH",
                    "CREDITS_USED": round(days * 0.27, 2),
                    "EXECUTION_HOURS": round(days * 1.1, 2),
                    "PERIOD_DAYS": days,
                },
            ]

        return QueryResult(
            query_id=f"mock-{uuid4()}",
            columns=list(rows[0]),
            rows=rows,
            row_count=len(rows),
        )
