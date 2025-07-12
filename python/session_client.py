"""
Redis client wrapper for session management.

This module provides a convenient wrapper around the Redis client
with session-specific functionality and error handling.
"""

import os
from typing import Any, Dict, Optional
from urllib.parse import urlparse

from dotenv import load_dotenv

import redis

from .session_manager import SessionManager

# Load environment variables
load_dotenv()


class SessionClient:
    """Redis client wrapper for session management."""

    def __init__(
        self,
        host: Optional[str] = None,
        port: Optional[int] = None,
        password: Optional[str] = None,
        db: Optional[int] = None,
        url: Optional[str] = None,
        **kwargs: Any,
    ) -> None:
        """
        Initialize the session client.

        Args:
            host: Redis host (defaults to REDIS_HOST env var)
            port: Redis port (defaults to REDIS_PORT env var)
            password: Redis password (defaults to REDIS_PASSWORD env var)
            db: Redis database number (defaults to REDIS_DB env var)
            url: Redis URL (overrides other connection params)
            **kwargs: Additional Redis client parameters
        """

        if url:
            # Parse Redis URL
            parsed = urlparse(url)
            host = parsed.hostname or host
            port = parsed.port or port
            password = parsed.password or password
            db = int(parsed.path.lstrip("/")) if parsed.path else db

        # Use environment variables as defaults
        self.host = host or os.getenv("REDIS_HOST", "localhost")
        self.port = port or int(os.getenv("REDIS_PORT", "6379"))
        self.password = password or os.getenv("REDIS_PASSWORD")
        self.db = db or int(os.getenv("REDIS_DB", "0"))

        # Create Redis client
        self.redis_client = redis.Redis(
            host=self.host,
            port=self.port,
            password=self.password,
            db=self.db,
            decode_responses=True,
            **kwargs,
        )

        # Create session manager
        self.session_manager = SessionManager(self.redis_client)

    def ping(self) -> bool:
        """Test Redis connection."""
        try:
            return bool(self.redis_client.ping())
        except redis.ConnectionError:
            return False

    def get_info(self) -> Dict[str, Any]:
        """Get Redis server information."""
        try:
            info = self.redis_client.info()
            if not isinstance(info, dict):
                return {"error": "Unexpected response type from Redis"}
            return info
        except redis.RedisError as e:
            return {"error": str(e)}

    def get_memory_info(self) -> Dict[str, Any]:
        """Get Redis memory information."""
        try:
            info = self.redis_client.info("memory")
            if not isinstance(info, dict):
                return {"error": "Unexpected response type from Redis"}
            return info
        except redis.RedisError as e:
            return {"error": str(e)}

    def get_session_stats(self) -> Dict[str, Any]:
        """Get session statistics."""
        try:
            return self.session_manager.get_session_stats()
        except redis.RedisError as e:
            return {"error": str(e)}

    def cleanup_expired_sessions(self) -> int:
        """Clean up expired sessions."""
        try:
            return self.session_manager.cleanup_expired_sessions()
        except redis.RedisError as e:
            print(f"Error cleaning up sessions: {e}")
            return 0

    def health_check(self) -> Dict[str, Any]:
        """Perform a comprehensive health check."""
        health_status: Dict[str, Any] = {
            "redis_connection": False,
            "ping": False,
            "session_stats": None,
            "memory_usage": None,
            "errors": [],
        }

        try:
            # Test connection
            health_status["redis_connection"] = True

            # Test ping
            if self.ping():
                health_status["ping"] = True
            else:
                health_status["errors"].append("Redis ping failed")

            # Get session stats
            try:
                health_status["session_stats"] = self.get_session_stats()
            except Exception as e:
                health_status["errors"].append(f"Failed to get session stats: {e}")

            # Get memory info
            try:
                health_status["memory_usage"] = self.get_memory_info()
            except Exception as e:
                health_status["errors"].append(f"Failed to get memory info: {e}")

        except Exception as e:
            health_status["errors"].append(f"Connection failed: {e}")

        return health_status


def create_session_client() -> SessionClient:
    """Create a session client with default configuration."""
    return SessionClient()


def create_session_client_from_url(url: str) -> SessionClient:
    """Create a session client from a Redis URL."""
    return SessionClient(url=url)
