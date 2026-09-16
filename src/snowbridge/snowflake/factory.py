from snowbridge.config import Settings
from snowbridge.snowflake.client import SnowflakeClient
from snowbridge.snowflake.mock_client import MockSnowflakeClient
from snowbridge.snowflake.real_client import RealSnowflakeClient


def create_snowflake_client(settings: Settings) -> SnowflakeClient:
    if settings.snowflake_backend == "snowflake":
        return RealSnowflakeClient(settings)
    return MockSnowflakeClient()
