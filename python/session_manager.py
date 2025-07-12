"""
Session Manager for Redis-based session storage.

This module provides a comprehensive session management system using Redis
for storing user sessions, tokens, and related metadata.
"""

import uuid
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field

import redis


class SessionData(BaseModel):
    """Model for session data structure."""

    user_id: str
    session_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    created_at: datetime = Field(default_factory=datetime.utcnow)
    expires_at: datetime
    is_active: bool = True
    metadata: Dict[str, Any] = Field(default_factory=dict)
    last_activity: datetime = Field(default_factory=datetime.utcnow)


class SessionManager:
    """Manages user sessions using Redis."""

    def __init__(self, redis_client: redis.Redis) -> None:
        self.redis = redis_client
        self.session_prefix = "session:"
        self.user_sessions_prefix = "user_sessions:"
        self.session_cleanup_key = "session_cleanup"

    def create_session(
        self,
        user_id: str,
        ttl_seconds: int = 3600,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> SessionData:
        """Create a new session for a user."""

        session_data = SessionData(
            user_id=user_id,
            expires_at=datetime.utcnow() + timedelta(seconds=ttl_seconds),
            metadata=metadata or {},
        )

        # Store session data
        session_key = f"{self.session_prefix}{session_data.session_id}"
        self.redis.setex(session_key, ttl_seconds, session_data.model_dump_json())

        # Add to user's session list
        user_sessions_key = f"{self.user_sessions_prefix}{user_id}"
        self.redis.sadd(user_sessions_key, session_data.session_id)
        self.redis.expire(user_sessions_key, ttl_seconds)

        # Add to cleanup set
        self.redis.zadd(
            self.session_cleanup_key,
            {session_data.session_id: session_data.expires_at.timestamp()},
        )

        return session_data

    def get_session(self, session_id: str) -> Optional[SessionData]:
        """Retrieve session data by session ID."""

        session_key = f"{self.session_prefix}{session_id}"
        session_json = self.redis.get(session_key)  # type: ignore[union-attr]

        if not session_json:
            return None

        session_data = SessionData.model_validate_json(
            session_json  # type: ignore[arg-type]
        )

        # Update last activity
        session_data.last_activity = datetime.utcnow()
        self.redis.setex(
            session_key,
            self._get_remaining_ttl(session_id),
            session_data.model_dump_json(),
        )

        return session_data

    def invalidate_session(self, session_id: str) -> bool:
        """Invalidate a specific session."""

        session_key = f"{self.session_prefix}{session_id}"
        session_json = self.redis.get(session_key)  # type: ignore[union-attr]

        if not session_json:
            return False

        session_data = SessionData.model_validate_json(
            session_json  # type: ignore[arg-type]
        )

        # Remove from Redis
        self.redis.delete(session_key)
        self.redis.zrem(self.session_cleanup_key, session_id)

        # Remove from user's session list
        user_sessions_key = f"{self.user_sessions_prefix}{session_data.user_id}"
        self.redis.srem(user_sessions_key, session_id)

        return True

    def invalidate_user_sessions(self, user_id: str) -> int:
        """Invalidate all sessions for a user."""

        user_sessions_key = f"{self.user_sessions_prefix}{user_id}"
        session_ids = self.redis.smembers(user_sessions_key)  # type: ignore[union-attr]

        if not session_ids:
            return 0

        # Remove all sessions
        for session_id in session_ids:  # type: ignore[union-attr]
            session_key = f"{self.session_prefix}{session_id.decode()}"
            self.redis.delete(session_key)
            self.redis.zrem(self.session_cleanup_key, session_id.decode())

        # Remove user sessions set
        self.redis.delete(user_sessions_key)

        return len(session_ids)  # type: ignore[arg-type]

    def get_user_sessions(self, user_id: str) -> List[SessionData]:
        """Get all active sessions for a user."""

        user_sessions_key = f"{self.user_sessions_prefix}{user_id}"
        session_ids = self.redis.smembers(user_sessions_key)  # type: ignore[union-attr]

        sessions = []
        for session_id in session_ids:  # type: ignore[union-attr]
            session_data = self.get_session(session_id.decode())
            if session_data and session_data.is_active:
                sessions.append(session_data)

        return sessions

    def cleanup_expired_sessions(self) -> int:
        """Clean up expired sessions."""

        current_time = datetime.utcnow().timestamp()
        expired_sessions = self.redis.zrangebyscore(
            self.session_cleanup_key, 0, current_time
        )  # type: ignore[union-attr]

        cleaned_count = 0
        for session_id in expired_sessions:  # type: ignore[union-attr]
            session_id_str = session_id.decode()
            if self.invalidate_session(session_id_str):
                cleaned_count += 1

        return cleaned_count  # type: ignore[return-value]

    def _get_remaining_ttl(self, session_id: str) -> int:
        """Get remaining TTL for a session."""

        session_key = f"{self.session_prefix}{session_id}"
        return self.redis.ttl(session_key)  # type: ignore[return-value]

    def get_session_stats(self) -> Dict[str, Any]:
        """Get session statistics."""

        total_sessions = self.redis.zcard(self.session_cleanup_key)
        current_time = datetime.utcnow().timestamp()
        active_sessions = self.redis.zcount(
            self.session_cleanup_key, current_time, "+inf"
        )

        return {
            "total_sessions": total_sessions,  # type: ignore[operator]
            "active_sessions": active_sessions,  # type: ignore[operator]
            "expired_sessions": (
                total_sessions - active_sessions  # type: ignore[operator]
            ),
        }
