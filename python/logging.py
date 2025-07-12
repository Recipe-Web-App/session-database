"""Logging setup and configuration using Python's standard logging module.

This module configures structured logging for the entire application, providing both
console and file logging with JSON formatting for structured log analysis.
"""

import json
import logging
import logging.handlers
import sys
from pathlib import Path
from typing import ClassVar

from .config import settings


class JsonFormatter(logging.Formatter):
    """Custom JSON formatter for structured logging."""

    def format(self, record: logging.LogRecord) -> str:
        """Format a log record as a JSON string."""
        log_entry = {
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
        }
        return json.dumps(log_entry)


class PrettyFormatter(logging.Formatter):
    """Pretty formatter for console output with colors."""

    # ANSI color codes
    COLORS: ClassVar[dict[str, str]] = {
        "DEBUG": "\033[36m",  # Cyan
        "INFO": "\033[32m",  # Green
        "WARNING": "\033[33m",  # Yellow
        "ERROR": "\033[31m",  # Red
        "CRITICAL": "\033[35m",  # Magenta
        "RESET": "\033[0m",  # Reset
        "GREEN": "\033[32m",  # Green for timestamp
        "CYAN": "\033[36m",  # Cyan for logger info
    }

    def format(self, record: logging.LogRecord) -> str:
        """Format a log record for console display with colors."""
        level_color = self.COLORS.get(record.levelname, "")
        level_reset = self.COLORS["RESET"]

        return (
            f"{self.COLORS['GREEN']}{self.formatTime(record)}{self.COLORS['RESET']} | "
            f"{level_color}{record.levelname:<8}{level_reset} | "
            f"{self.COLORS['CYAN']}{record.name}:{record.funcName}:"
            f"{record.lineno}{self.COLORS['RESET']}"
            f" | {level_color}{record.getMessage()}{level_reset}"
        )


def configure_logging() -> None:
    """Configure global application logging using settings-based config."""
    # Set third-party loggers to WARNING to reduce noise
    logging.getLogger("redis").setLevel(logging.WARNING)
    logging.getLogger("urllib3").setLevel(logging.WARNING)

    log_dir = Path("./logs")
    log_dir.mkdir(exist_ok=True)

    root_logger = logging.getLogger()
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)

    for sink in settings.logging_sinks:
        if sink.sink == "sys.stdout":
            console_handler = logging.StreamHandler(sys.stdout)
            console_handler.setLevel(getattr(logging, sink.level or "INFO"))
            console_handler.setFormatter(PrettyFormatter())
            root_logger.addHandler(console_handler)
        elif isinstance(sink.sink, str) and sink.sink.endswith(".log"):
            file_handler = logging.handlers.RotatingFileHandler(
                sink.sink, maxBytes=10 * 1024 * 1024, backupCount=5
            )
            file_handler.setLevel(getattr(logging, sink.level or "DEBUG"))
            file_handler.setFormatter(JsonFormatter())
            root_logger.addHandler(file_handler)

    if root_logger.handlers:
        min_level = min(handler.level for handler in root_logger.handlers)
        root_logger.setLevel(min_level)


def get_logger(name: str | None = None) -> logging.Logger:
    """Retrieve a configured logger instance.

    Args:
        name: Optional logical name to bind to the logger.
              If None, uses the calling module's name.

    Returns:
        logging.Logger: A configured logger instance.
    """
    return logging.getLogger(name or __name__)
