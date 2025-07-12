"""
Redis connection utilities.

This module provides utilities for managing Redis connections
with proper error handling and connection pooling.
"""

import os
from typing import Any, Dict, Optional
from urllib.parse import urlparse

from dotenv import load_dotenv

import redis

# Load environment variables
load_dotenv()


class RedisConnection:
    """Redis connection manager with connection pooling and error handling."""

    def __init__(
        self,
        host: Optional[str] = None,
        port: Optional[int] = None,
        password: Optional[str] = None,
        db: Optional[int] = None,
        url: Optional[str] = None,
        max_connections: int = 10,
        **kwargs: Any,
    ) -> None:
        """
        Initialize Redis connection.

        Args:
            host: Redis host
            port: Redis port
            password: Redis password
            db: Redis database number
            url: Redis URL
            max_connections: Maximum number of connections in pool
            **kwargs: Additional Redis client parameters
        """

        if url:
            parsed = urlparse(url)
            host = parsed.hostname or host
            port = parsed.port or port
            password = parsed.password or password
            db = int(parsed.path.lstrip("/")) if parsed.path else db

        self.host = host or os.getenv("REDIS_HOST", "localhost")
        self.port = port or int(os.getenv("REDIS_PORT", "6379"))
        self.password = password or os.getenv("REDIS_PASSWORD")
        self.db = db or int(os.getenv("REDIS_DB", "0"))

        # Create connection pool
        self.pool = redis.ConnectionPool(
            host=self.host,
            port=self.port,
            password=self.password,
            db=self.db,
            max_connections=max_connections,
            decode_responses=True,
            **kwargs,
        )

        self.client: Optional[redis.Redis] = None

    def get_client(self) -> redis.Redis:
        """Get Redis client instance."""
        if self.client is None:
            self.client = redis.Redis(
                connection_pool=self.pool
            )  # type: ignore[assignment]
        return self.client

    def test_connection(self) -> bool:
        """Test Redis connection."""
        try:
            client = self.get_client()
            return bool(client.ping())  # type: ignore[arg-type]
        except Exception:
            return False

    def get_connection_info(self) -> Dict[str, Any]:
        """Get connection information."""
        return {
            "host": self.host,
            "port": self.port,
            "db": self.db,
            "has_password": bool(self.password),
            "pool_size": self.pool.max_connections,
        }

    def close(self) -> None:
        """Close all connections in the pool."""
        if self.pool:
            self.pool.disconnect()
