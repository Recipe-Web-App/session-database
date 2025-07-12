#!/bin/bash
# Redis startup script with environment variable substitution

set -e

# Substitute environment variables in the Redis config template
envsubst < /usr/local/etc/redis/redis.conf.template > /usr/local/etc/redis/redis.conf

# Start Redis with the processed config
exec redis-server /usr/local/etc/redis/redis.conf
