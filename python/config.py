"""Application configuration settings.

Defines and loads configuration variables and settings used across the application,
including environment-specific and default configurations.
"""

import json
from pathlib import Path
from typing import Any

from pydantic import Field, PrivateAttr
from pydantic_settings import BaseSettings, SettingsConfigDict


class LoggingSink:
    """Represents a single logging sink configuration.

    Attributes:
        sink: The sink target (e.g., file path or sys.stdout).
        level: The log level for this sink (e.g., "INFO", "DEBUG").
        serialize: Whether to serialize logs as JSON.
        rotation: Log rotation policy (e.g., "10 MB").
        retention: Log retention policy (e.g., "10 days").
        compression: Compression for rotated logs (e.g., "zip").
        colorize: Enable colored output for console sinks.
        catch: Catch sink exceptions.
    """

    def __init__(  # noqa: PLR0913
        self,
        sink: Any,
        level: str | None = None,
        serialize: bool | None = None,
        rotation: str | None = None,
        retention: str | None = None,
        compression: str | None = None,
        colorize: bool | None = None,
        catch: bool | None = None,
    ) -> None:
        """Initialize LoggingSink."""
        self.sink = sink
        self.level = level
        self.serialize = serialize
        self.rotation = rotation
        self.retention = retention
        self.compression = compression
        self.colorize = colorize
        self.catch = catch

    @staticmethod
    def from_dict(data: dict[str, Any]) -> "LoggingSink":
        """Create a LoggingSink instance from a dictionary."""
        return LoggingSink(
            sink=data.get("sink"),
            level=data.get("level"),
            serialize=data.get("serialize"),
            rotation=data.get("rotation"),
            retention=data.get("retention"),
            compression=data.get("compression"),
            colorize=data.get("colorize"),
            catch=data.get("catch"),
        )


class _Settings(BaseSettings):
    """Application settings loaded from environment variables or .env file."""

    # Redis Configuration
    REDIS_HOST: str = Field(..., alias="REDIS_HOST")
    REDIS_PORT: int = Field(..., alias="REDIS_PORT")
    REDIS_PASSWORD: str = Field(..., alias="REDIS_PASSWORD")
    REDIS_DB: int = Field(..., alias="REDIS_DB")

    # Session Configuration
    SESSION_TTL_SECONDS: int = Field(..., alias="SESSION_TTL_SECONDS")
    MAX_SESSIONS_PER_USER: int = Field(..., alias="MAX_SESSIONS_PER_USER")
    CLEANUP_INTERVAL_SECONDS: int = Field(..., alias="CLEANUP_INTERVAL_SECONDS")
    LOG_LEVEL: str = Field(..., alias="LOG_LEVEL")

    LOGGING_CONFIG_PATH: str = Field(
        str(
            (Path(__file__).parent.parent / "config" / "logging.json").resolve(),
        ),
        alias="LOGGING_CONFIG_PATH",
    )

    _LOGGING_SINKS: list["LoggingSink"] = PrivateAttr(default_factory=list)

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        validate_default=True,
    )

    def __init__(self) -> None:
        """Load logging config after Pydantic initialization."""
        super().__init__()

        # Load logging configuration
        config_path = Path(self.LOGGING_CONFIG_PATH).expanduser().resolve()
        with config_path.open("r", encoding="utf-8") as f:
            config = json.load(f)
        sinks = config.get("sinks", [])
        self._LOGGING_SINKS = [
            LoggingSink.from_dict(s) for s in sinks if isinstance(s, dict)
        ]

    @property
    def redis_host(self) -> str:
        """Get Redis host."""
        return self.REDIS_HOST

    @property
    def redis_port(self) -> int:
        """Get Redis port."""
        return self.REDIS_PORT

    @property
    def redis_password(self) -> str:
        """Get Redis password."""
        return self.REDIS_PASSWORD

    @property
    def redis_db(self) -> int:
        """Get Redis database number."""
        return self.REDIS_DB

    @property
    def session_ttl_seconds(self) -> int:
        """Get session TTL in seconds."""
        return self.SESSION_TTL_SECONDS

    @property
    def max_sessions_per_user(self) -> int:
        """Get maximum sessions per user."""
        return self.MAX_SESSIONS_PER_USER

    @property
    def cleanup_interval_seconds(self) -> int:
        """Get cleanup interval in seconds."""
        return self.CLEANUP_INTERVAL_SECONDS

    @property
    def log_level(self) -> str:
        """Get log level."""
        return self.LOG_LEVEL

    @property
    def logging_sinks(self) -> list["LoggingSink"]:
        """Get all configured logging sinks."""
        return self._LOGGING_SINKS

    @property
    def logging_stdout_sink(self) -> LoggingSink | None:
        """Get the stdout logging sink configuration."""
        return next(
            (sink for sink in self._LOGGING_SINKS if sink.sink == "sys.stdout"),
            None,
        )

    @property
    def logging_file_sink(self) -> LoggingSink | None:
        """Get the file logging sink configuration."""
        return next(
            (
                sink
                for sink in self._LOGGING_SINKS
                if isinstance(sink.sink, str) and sink.sink.endswith(".log")
            ),
            None,
        )


settings = _Settings()
