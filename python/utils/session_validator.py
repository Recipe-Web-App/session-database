"""
Session validation utilities.

This module provides utilities for validating session data
and ensuring session integrity.
"""

import re
import uuid
from datetime import datetime
from typing import Any, Dict, List

from pydantic import BaseModel, Field, validator


class SessionValidationError(Exception):
    """Exception raised for session validation errors."""

    pass


class SessionValidator(BaseModel):
    """Validator for session data."""

    user_id: str = Field(..., min_length=1, max_length=255)
    session_id: str = Field(..., min_length=1)
    created_at: datetime
    expires_at: datetime
    is_active: bool = True
    metadata: Dict[str, Any] = Field(default_factory=dict)
    last_activity: datetime

    @validator("user_id")
    def validate_user_id(cls, v: str) -> str:
        """Validate user ID format."""
        if not re.match(r"^[a-zA-Z0-9_-]+$", v):
            raise ValueError(
                "User ID must contain only alphanumeric characters, hyphens, and "
                "underscores"
            )
        return v

    @validator("session_id")
    def validate_session_id(cls, v: str) -> str:
        """Validate session ID format."""
        try:
            uuid.UUID(v)
        except ValueError:
            raise ValueError("Session ID must be a valid UUID")
        return v

    @validator("expires_at")
    def validate_expires_at(cls, v: datetime, values: Dict[str, Any]) -> datetime:
        """Validate expiration time."""
        if "created_at" in values and v <= values["created_at"]:
            raise ValueError("Expiration time must be after creation time")
        return v

    @validator("last_activity")
    def validate_last_activity(cls, v: datetime, values: Dict[str, Any]) -> datetime:
        """Validate last activity time."""
        if "created_at" in values and v < values["created_at"]:
            raise ValueError("Last activity cannot be before creation time")
        return v

    def is_expired(self) -> bool:
        """Check if session is expired."""
        return datetime.utcnow() > self.expires_at

    def get_remaining_ttl(self) -> int:
        """Get remaining time to live in seconds."""
        remaining = self.expires_at - datetime.utcnow()
        return max(0, int(remaining.total_seconds()))

    def is_stale(self, max_idle_time: int = 3600) -> bool:
        """Check if session is stale based on last activity."""
        idle_time = datetime.utcnow() - self.last_activity
        return idle_time.total_seconds() > max_idle_time


def validate_session_data(data: Dict[str, Any]) -> SessionValidator:
    """Validate session data dictionary."""
    try:
        return SessionValidator(**data)
    except Exception as e:
        raise SessionValidationError(f"Invalid session data: {e}")


def validate_session_id(session_id: str) -> bool:
    """Validate session ID format."""
    try:
        uuid.UUID(session_id)
        return True
    except ValueError:
        return False


def validate_user_id(user_id: str) -> bool:
    """Validate user ID format."""
    if not user_id or len(user_id) > 255:
        return False
    return bool(re.match(r"^[a-zA-Z0-9_-]+$", user_id))


def validate_metadata(metadata: Dict[str, Any]) -> List[str]:
    """Validate session metadata and return list of warnings."""
    warnings = []

    # Check metadata size
    metadata_str = str(metadata)
    if len(metadata_str) > 1024:
        warnings.append("Metadata size exceeds recommended limit of 1KB")

    # Check for sensitive fields
    sensitive_keys = ["password", "token", "secret", "key"]
    for key in metadata:
        if any(sensitive in key.lower() for sensitive in sensitive_keys):
            warnings.append(f"Metadata contains potentially sensitive key: {key}")

    return warnings


def sanitize_session_data(data: Dict[str, Any]) -> Dict[str, Any]:
    """Sanitize session data for storage."""
    sanitized = data.copy()

    # Remove None values
    sanitized = {k: v for k, v in sanitized.items() if v is not None}

    # Ensure required fields
    required_fields = ["user_id", "session_id", "created_at", "expires_at"]
    for field in required_fields:
        if field not in sanitized:
            raise SessionValidationError(f"Missing required field: {field}")

    return sanitized
