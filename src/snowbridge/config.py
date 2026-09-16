from functools import lru_cache
from typing import Literal

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="SNOWBRIDGE_",
        extra="ignore",
    )

    app_name: str = "Snowbridge"
    environment: str = "development"
    snowflake_backend: Literal["mock", "snowflake"] = "mock"

    snowflake_account: str | None = None
    snowflake_user: str | None = None
    snowflake_password: SecretStr | None = None
    snowflake_private_key_path: str | None = None
    snowflake_private_key_passphrase: SecretStr | None = None
    snowflake_warehouse: str | None = None
    snowflake_database: str | None = None
    snowflake_schema: str | None = None
    snowflake_role: str | None = None
    snowflake_login_timeout_seconds: int = 15
    snowflake_network_timeout_seconds: int = 30


@lru_cache
def get_settings() -> Settings:
    return Settings()
