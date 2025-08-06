#!/bin/bash
# scripts/jobHelpers/session-cleanup.sh
# Session cleanup orchestration script for CronJob

set -euo pipefail

echo "$(date -Iseconds) Starting session cleanup job..."

# Test Redis connection
if ! redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
  -a "$REDIS_PASSWORD" ping > /dev/null 2>&1; then
  echo "$(date -Iseconds) ERROR: Cannot connect to Redis"
  exit 1
fi

echo "$(date -Iseconds) Redis connection successful"

# Execute cleanup script
CLEANUP_RESULT=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
    -a "$REDIS_PASSWORD" --eval /scripts/jobHelpers/session-cleanup.lua \
  "${CLEANUP_BATCH_SIZE}")

echo "$(date -Iseconds) Cleanup completed: $CLEANUP_RESULT"

# Parse and log results
echo "$CLEANUP_RESULT" | python3 /scripts/jobHelpers/parse-cleanup-results.py

echo "$(date -Iseconds) Session cleanup job completed successfully"
