"""
Tests for the session manager module.
"""

from datetime import datetime, timedelta
from unittest.mock import Mock

import pytest

from python.session_manager import SessionData, SessionManager


class TestSessionManager:
    """Test cases for SessionManager class."""

    @pytest.fixture
    def redis_mock(self) -> Mock:
        """Create a mock Redis client."""
        mock = Mock()
        mock.setex.return_value = True
        mock.sadd.return_value = 1
        mock.expire.return_value = True
        mock.zadd.return_value = 1
        mock.get.return_value = None
        mock.delete.return_value = 1
        mock.zrem.return_value = 1
        mock.srem.return_value = 1
        mock.smembers.return_value = []
        mock.zcard.return_value = 0
        mock.zcount.return_value = 0
        mock.zrangebyscore.return_value = []
        return mock

    @pytest.fixture
    def session_manager(self, redis_mock: Mock) -> SessionManager:
        """Create a SessionManager instance with mock Redis."""
        return SessionManager(redis_mock)

    def test_create_session(
        self,
        session_manager: SessionManager,
        redis_mock: Mock,
    ) -> None:
        """Test session creation."""
        user_id = "test_user"
        ttl_seconds = 3600
        metadata = {"ip": "192.168.1.1"}

        session = session_manager.create_session(user_id, ttl_seconds, metadata)

        assert session.user_id == user_id
        assert session.metadata == metadata
        assert session.is_active is True
        assert session.expires_at > datetime.utcnow()

        # Verify Redis calls
        redis_mock.setex.assert_called_once()
        redis_mock.sadd.assert_called_once()
        redis_mock.zadd.assert_called_once()

    def test_get_session_not_found(
        self,
        session_manager: SessionManager,
        redis_mock: Mock,
    ) -> None:
        """Test getting a non-existent session."""
        redis_mock.get.return_value = None

        result = session_manager.get_session("non_existent_session")

        assert result is None

    def test_get_session_found(
        self,
        session_manager: SessionManager,
        redis_mock: Mock,
    ) -> None:
        """Test getting an existing session."""
        session_data = SessionData(
            user_id="test_user",
            session_id="test_session",
            expires_at=datetime.utcnow() + timedelta(hours=1),
        )

        redis_mock.get.return_value = session_data.model_dump_json()
        redis_mock.ttl.return_value = 3600

        result = session_manager.get_session("test_session")

        assert result is not None
        assert result.user_id == "test_user"
        assert result.session_id == "test_session"

    def test_invalidate_session(
        self,
        session_manager: SessionManager,
        redis_mock: Mock,
    ) -> None:
        """Test session invalidation."""
        session_data = SessionData(
            user_id="test_user",
            session_id="test_session",
            expires_at=datetime.utcnow() + timedelta(hours=1),
        )

        redis_mock.get.return_value = session_data.model_dump_json()

        result = session_manager.invalidate_session("test_session")

        assert result is True
        redis_mock.delete.assert_called_once()
        redis_mock.zrem.assert_called_once()
        redis_mock.srem.assert_called_once()

    def test_invalidate_session_not_found(
        self,
        session_manager: SessionManager,
        redis_mock: Mock,
    ) -> None:
        """Test invalidating a non-existent session."""
        redis_mock.get.return_value = None

        result = session_manager.invalidate_session("non_existent_session")

        assert result is False

    def test_get_session_stats(
        self,
        session_manager: SessionManager,
        redis_mock: Mock,
    ) -> None:
        """Test getting session statistics."""
        redis_mock.zcard.return_value = 10
        redis_mock.zcount.return_value = 8

        stats = session_manager.get_session_stats()

        assert stats["total_sessions"] == 10
        assert stats["active_sessions"] == 8
        assert stats["expired_sessions"] == 2

    def test_cleanup_expired_sessions(
        self,
        session_manager: SessionManager,
        redis_mock: Mock,
    ) -> None:
        """Test cleanup of expired sessions."""
        redis_mock.zrangebyscore.return_value = [
            b"expired_session_1",
            b"expired_session_2",
        ]
        redis_mock.get.return_value = SessionData(
            user_id="test_user",
            session_id="expired_session_1",
            expires_at=datetime.utcnow() - timedelta(hours=1),
        ).model_dump_json()

        cleaned_count = session_manager.cleanup_expired_sessions()

        assert cleaned_count == 2
        assert redis_mock.delete.call_count == 2
        assert redis_mock.zrem.call_count == 2


class TestSessionData:
    """Test cases for SessionData model."""

    def test_session_data_creation(self) -> None:
        """Test SessionData model creation."""
        user_id = "test_user"
        session_id = "test_session"
        expires_at = datetime.utcnow() + timedelta(hours=1)

        session_data = SessionData(
            user_id=user_id, session_id=session_id, expires_at=expires_at
        )

        assert session_data.user_id == user_id
        assert session_data.session_id == session_id
        assert session_data.expires_at == expires_at
        assert session_data.is_active is True
        assert session_data.metadata == {}

    def test_session_data_with_metadata(self) -> None:
        """Test SessionData creation with metadata."""
        metadata = {"ip": "192.168.1.1", "user_agent": "Mozilla/5.0"}

        session_data = SessionData(
            user_id="test_user",
            expires_at=datetime.utcnow() + timedelta(hours=1),
            metadata=metadata,
        )

        assert session_data.metadata == metadata
