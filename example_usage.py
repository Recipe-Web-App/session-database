#!/usr/bin/env python3
"""
Example usage of the session database.

This script demonstrates how to use the session management system
with Redis for storing and managing user sessions.
"""

import os
import sys
from datetime import datetime

from python.session_client import SessionClient

# Add the python directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "python"))


def main() -> None:
    """Demonstrate session management functionality."""

    print("🚀 Session Database Example Usage")
    print("=" * 50)

    # Create session client
    print("\n📡 Connecting to Redis...")
    try:
        client = SessionClient()

        # Test connection
        if not client.ping():
            print("❌ Failed to connect to Redis")
            return

        print("✅ Connected to Redis successfully")

    except Exception as e:
        print(f"❌ Connection error: {e}")
        return

    # Get session manager
    session_manager = client.session_manager

    print("\n📊 Current session statistics:")
    stats = session_manager.get_session_stats()
    for key, value in stats.items():
        print(f"  {key}: {value}")

    # Create a test session
    print("\n🔐 Creating test session...")
    user_id = "example_user_123"
    metadata = {
        "ip": "192.168.1.100",
        "user_agent": "Mozilla/5.0 (Example Browser)",
        "login_time": datetime.utcnow().isoformat(),
    }

    session = session_manager.create_session(
        user_id=user_id, ttl_seconds=3600, metadata=metadata  # 1 hour
    )

    print(f"✅ Created session: {session.session_id}")
    print(f"  User ID: {session.user_id}")
    print(f"  Expires: {session.expires_at}")
    print(f"  Metadata: {session.metadata}")

    # Retrieve the session
    print("\n🔍 Retrieving session...")
    retrieved_session = session_manager.get_session(session.session_id)

    if retrieved_session:
        print(f"✅ Retrieved session: {retrieved_session.session_id}")
        print(f"  Last activity: {retrieved_session.last_activity}")
    else:
        print("❌ Session not found")

    # Get user's sessions
    print("\n👤 Getting user sessions...")
    user_sessions = session_manager.get_user_sessions(user_id)
    print(f"✅ User has {len(user_sessions)} active sessions")

    for i, sess in enumerate(user_sessions, 1):
        print(f"  Session {i}: {sess.session_id}")
        print(f"    Created: {sess.created_at}")
        print(f"    Expires: {sess.expires_at}")

    # Demonstrate session invalidation
    print("\n🗑️  Invalidating session...")
    if session_manager.invalidate_session(session.session_id):
        print("✅ Session invalidated successfully")
    else:
        print("❌ Failed to invalidate session")

    # Verify session is gone
    print("\n🔍 Verifying session is invalidated...")
    invalidated_session = session_manager.get_session(session.session_id)
    if invalidated_session is None:
        print("✅ Session successfully invalidated")
    else:
        print("❌ Session still exists")

    # Cleanup expired sessions
    print("\n🧹 Cleaning up expired sessions...")
    cleaned_count = session_manager.cleanup_expired_sessions()
    print(f"✅ Cleaned up {cleaned_count} expired sessions")

    # Final statistics
    print("\n📊 Final session statistics:")
    final_stats = session_manager.get_session_stats()
    for key, value in final_stats.items():
        print(f"  {key}: {value}")

    print("\n✅ Example completed successfully!")


if __name__ == "__main__":
    main()
