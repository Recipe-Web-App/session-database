#!/bin/bash
# Lua script initialization for Redis session management

set -e

echo "Waiting for Redis to be ready..."

# Wait for Redis to be responsive
until redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ${REDIS_PASSWORD:+-a "$REDIS_PASSWORD"} ping > /dev/null 2>&1; do
  echo "Waiting for Redis connection..."
  sleep 2
done

echo "✅ Redis is ready for initialization"

# Initialize session management system with Lua scripts
echo "Initializing session management system..."

# Run initialization scripts
if [ -n "${REDIS_PASSWORD:-}" ]; then
  # Initialize session keys and structures
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" --eval /usr/local/etc/redis/scripts/001_init_session_keys.lua
  echo "✅ Session keys initialized"

  # Initialize user session tracking
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" --eval /usr/local/etc/redis/scripts/002_init_user_sessions.lua
  echo "✅ User session tracking initialized"

  # Initialize session cleanup
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" --eval /usr/local/etc/redis/scripts/003_init_session_cleanup.lua
  echo "✅ Session cleanup initialized"

  # Initialize refresh token management
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" --eval /usr/local/etc/redis/scripts/004_init_refresh_tokens.lua
  echo "✅ Refresh token management initialized"

  # Initialize deletion token management
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" --eval /usr/local/etc/redis/scripts/005_init_deletion_tokens.lua
  echo "✅ Deletion token management initialized"
else
  # Initialize session keys and structures
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" --eval /usr/local/etc/redis/scripts/001_init_session_keys.lua
  echo "✅ Session keys initialized"

  # Initialize user session tracking
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" --eval /usr/local/etc/redis/scripts/002_init_user_sessions.lua
  echo "✅ User session tracking initialized"

  # Initialize session cleanup
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" --eval /usr/local/etc/redis/scripts/003_init_session_cleanup.lua
  echo "✅ Session cleanup initialized"

  # Initialize refresh token management
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" --eval /usr/local/etc/redis/scripts/004_init_refresh_tokens.lua
  echo "✅ Refresh token management initialized"

  # Initialize deletion token management
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" --eval /usr/local/etc/redis/scripts/005_init_deletion_tokens.lua
  echo "✅ Deletion token management initialized"
fi

echo "🎉 Session management system initialization complete!"
