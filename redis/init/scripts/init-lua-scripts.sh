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

# Initialize auth service system with Lua scripts
echo "Initializing auth service system..."

# Run initialization scripts
if [ -n "${REDIS_PASSWORD:-}" ]; then
  # Initialize auth service structures
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" --eval /usr/local/etc/redis/scripts/001_init_auth_service.lua
  echo "✅ Auth service initialized"

  # Initialize service cache (DB 1)
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" --eval /usr/local/etc/redis/scripts/006_init_service_cache.lua
  echo "✅ Service cache initialized in DB 1"

  # Initialize cache cleanup system
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" --eval /usr/local/etc/redis/scripts/007_init_cache_cleanup.lua
  echo "✅ Cache cleanup system initialized"
else
  # Initialize auth service structures
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" --eval /usr/local/etc/redis/scripts/001_init_auth_service.lua
  echo "✅ Auth service initialized"

  # Initialize service cache (DB 1)
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" --eval /usr/local/etc/redis/scripts/006_init_service_cache.lua
  echo "✅ Service cache initialized in DB 1"

  # Initialize cache cleanup system
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" --eval /usr/local/etc/redis/scripts/007_init_cache_cleanup.lua
  echo "✅ Cache cleanup system initialized"
fi

echo "🎉 Auth service system initialization complete!"
