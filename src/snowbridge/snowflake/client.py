from typing import Any, Protocol

from snowbridge.models import ConnectionStatus, OperationName, QueryResult


class SnowflakeClient(Protocol):
    def test_connection(self) -> ConnectionStatus: ...

    def execute(
        self,
        operation: OperationName,
        parameters: dict[str, Any],
    ) -> QueryResult: ...


class SnowflakeClientError(RuntimeError):
    """Base exception for normalized Snowflake adapter failures."""


class InvalidOperationParametersError(SnowflakeClientError):
    """Raised when an approved operation receives invalid parameters."""


class SnowflakeConfigurationError(SnowflakeClientError):
    """Raised when the real backend is missing required configuration."""
