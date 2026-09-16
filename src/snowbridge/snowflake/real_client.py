from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import Any

from snowbridge.config import Settings
from snowbridge.models import ConnectionStatus, OperationName, QueryResult
from snowbridge.snowflake.client import (
    InvalidOperationParametersError,
    SnowflakeClientError,
    SnowflakeConfigurationError,
)


class RealSnowflakeClient:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    @contextmanager
    def _connect(self) -> Iterator[Any]:
        try:
            import snowflake.connector
        except ImportError as exc:
            raise SnowflakeConfigurationError(
                "Install the Snowflake dependencies with 'uv sync --extra snowflake'."
            ) from exc

        connection_options = self._connection_options()
        try:
            connection = snowflake.connector.connect(**connection_options)
        except Exception as exc:
            raise SnowflakeClientError("Unable to connect to Snowflake.") from exc

        try:
            yield connection
        finally:
            connection.close()

    def _connection_options(self) -> dict[str, Any]:
        settings = self._settings
        missing = [
            name
            for name, value in {
                "SNOWBRIDGE_SNOWFLAKE_ACCOUNT": settings.snowflake_account,
                "SNOWBRIDGE_SNOWFLAKE_USER": settings.snowflake_user,
            }.items()
            if not value
        ]
        if missing:
            raise SnowflakeConfigurationError(
                f"Missing required Snowflake configuration: {', '.join(missing)}."
            )

        options: dict[str, Any] = {
            "account": settings.snowflake_account,
            "user": settings.snowflake_user,
            "warehouse": settings.snowflake_warehouse,
            "database": settings.snowflake_database,
            "schema": settings.snowflake_schema,
            "role": settings.snowflake_role,
            "login_timeout": settings.snowflake_login_timeout_seconds,
            "network_timeout": settings.snowflake_network_timeout_seconds,
            "application": "SNOWBRIDGE",
        }

        if settings.snowflake_private_key_path:
            options["private_key_file"] = str(Path(settings.snowflake_private_key_path))
            if settings.snowflake_private_key_passphrase:
                options["private_key_file_pwd"] = (
                    settings.snowflake_private_key_passphrase.get_secret_value()
                )
        elif settings.snowflake_password:
            options["password"] = settings.snowflake_password.get_secret_value()
        else:
            raise SnowflakeConfigurationError(
                "Configure a Snowflake private key or password before using the real backend."
            )

        return {key: value for key, value in options.items() if value is not None}

    def test_connection(self) -> ConnectionStatus:
        with self._connect() as connection, connection.cursor() as cursor:
            cursor.execute("SELECT CURRENT_ACCOUNT()")
            account_name = cursor.fetchone()[0]
        return ConnectionStatus(
            connected=True,
            backend="snowflake",
            detail=f"Connected to Snowflake account {account_name}.",
        )

    def execute(
        self,
        operation: OperationName,
        parameters: dict[str, Any],
    ) -> QueryResult:
        sql, bindings = self._operation_query(operation, parameters)
        try:
            with self._connect() as connection, connection.cursor() as cursor:
                cursor.execute(sql, bindings)
                column_names = [column.name for column in cursor.description]
                rows = [dict(zip(column_names, row, strict=True)) for row in cursor.fetchall()]
                query_id = cursor.sfqid
        except SnowflakeClientError:
            raise
        except Exception as exc:
            raise SnowflakeClientError("Snowflake operation failed.") from exc

        return QueryResult(
            query_id=query_id,
            columns=column_names,
            rows=rows,
            row_count=len(rows),
        )

    @staticmethod
    def _operation_query(
        operation: OperationName,
        parameters: dict[str, Any],
    ) -> tuple[str, dict[str, Any]]:
        if operation is OperationName.ECHO:
            message = parameters.get("message")
            if not isinstance(message, str) or not message:
                raise InvalidOperationParametersError(
                    "The echo operation requires a non-empty string parameter named 'message'."
                )
            return "SELECT %(message)s AS MESSAGE", {"message": message}

        return (
            "SELECT CURRENT_ACCOUNT() AS ACCOUNT_NAME, "
            "CURRENT_USER() AS USER_NAME, CURRENT_ROLE() AS ROLE_NAME, "
            "CURRENT_WAREHOUSE() AS WAREHOUSE_NAME",
            {},
        )
