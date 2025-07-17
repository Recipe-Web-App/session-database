#!/bin/bash
# Redis startup script with environment variable substitution and Lua script initialization

set -e

# Substitute environment variables in the Redis config template
envsubst < /usr/local/etc/redis/redis.conf.template > /usr/local/etc/redis/redis.conf

# Start Redis in the background for initialization
redis-server /usr/local/etc/redis/redis.conf --daemonize yes

# Wait for Redis to be ready
sleep 2

# Initialize session management system with Lua scripts
echo "Initializing session management system..."

# Run initialization scripts
if [ -n "${REDIS_PASSWORD:-}" ]; then
  # Initialize session keys and structures
  redis-cli -a "$REDIS_PASSWORD" --eval /usr/local/etc/redis/scripts/001_init_session_keys.lua
  echo "✅ Session keys initialized"

  # Initialize user session tracking
  redis-cli -a "$REDIS_PASSWORD" --eval /usr/local/etc/redis/scripts/002_init_user_sessions.lua
  echo "✅ User session tracking initialized"

  # Initialize session cleanup
  redis-cli -a "$REDIS_PASSWORD" --eval /usr/local/etc/redis/scripts/003_init_session_cleanup.lua
  echo "✅ Session cleanup initialized"

  # Initialize refresh token management
  redis-cli -a "$REDIS_PASSWORD" --eval /usr/local/etc/redis/scripts/004_init_refresh_tokens.lua
  echo "✅ Refresh token management initialized"

  # Initialize deletion token management
  redis-cli -a "$REDIS_PASSWORD" --eval /usr/local/etc/redis/scripts/005_init_deletion_tokens.lua
  echo "✅ Deletion token management initialized"
else
  # Initialize session keys and structures
  redis-cli --eval /usr/local/etc/redis/scripts/001_init_session_keys.lua
  echo "✅ Session keys initialized"

  # Initialize user session tracking
  redis-cli --eval /usr/local/etc/redis/scripts/002_init_user_sessions.lua
  echo "✅ User session tracking initialized"

  # Initialize session cleanup
  redis-cli --eval /usr/local/etc/redis/scripts/003_init_session_cleanup.lua
  echo "✅ Session cleanup initialized"

  # Initialize refresh token management
  redis-cli --eval /usr/local/etc/redis/scripts/004_init_refresh_tokens.lua
  echo "✅ Refresh token management initialized"

  # Initialize deletion token management
  redis-cli --eval /usr/local/etc/redis/scripts/005_init_deletion_tokens.lua
  echo "✅ Deletion token management initialized"
fi

# Stop the background Redis process
redis-cli ${REDIS_PASSWORD:+-a "$REDIS_PASSWORD"} shutdown

# Wait for shutdown
sleep 2

# Start Redis in foreground (main process)
echo "Starting Redis with advanced session management..."
exec redis-server /usr/local/etc/redis/redis.conf
