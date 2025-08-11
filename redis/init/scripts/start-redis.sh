#!/bin/bash
# Redis startup script with environment variable substitution and Lua script initialization

set -e

# Substitute environment variables in the Redis config template
envsubst < /usr/local/etc/redis/redis.conf.template > /config/redis.conf

# Start Redis in foreground (main process)
exec redis-server /config/redis.conf
