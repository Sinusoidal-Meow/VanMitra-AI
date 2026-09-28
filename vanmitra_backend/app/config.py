"""Application settings, read from environment variables (prefix VANMITRA_) or .env."""

from functools import lru_cache

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_DEV_JWT_SECRET = "dev-only-change-me"  # noqa: S105 (refused when env=production)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_prefix="VANMITRA_", extra="ignore")

    env: str = "development"  # development | test | production

    database_url: str = "postgresql+psycopg://vanmitra:vanmitra@localhost:5432/vanmitra"
    db_connect_timeout_s: int = 3

    jwt_secret: str = _DEV_JWT_SECRET
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 30
    refresh_token_days: int = 30

    cors_origins: list[str] = ["*"]

    # Old "Model A" AI endpoints, kept until the app migrates (BACKEND_PLAN B-04).
    enable_legacy_api: bool = True

    @model_validator(mode="after")
    def _no_dev_secret_in_production(self) -> "Settings":
        if self.env == "production" and self.jwt_secret == _DEV_JWT_SECRET:
            raise ValueError("VANMITRA_JWT_SECRET must be set in production")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
