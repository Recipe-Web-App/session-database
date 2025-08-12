#!/bin/bash
# scripts/jobHelpers/cache-cleanup.sh
# Cache cleanup orchestration script for CronJob

set -euo pipefail

echo "$(date -Iseconds) Starting cache cleanup job for DB 1..."

# Test Redis connection
if ! redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
  -a "$REDIS_PASSWORD" ping > /dev/null 2>&1; then
  echo "$(date -Iseconds) ERROR: Cannot connect to Redis"
  exit 1
fi

echo "$(date -Iseconds) Redis connection successful"

# Switch to cache database and verify
CACHE_DB_CHECK=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
  -a "$REDIS_PASSWORD" -n "${CACHE_DB:-1}" ping 2>/dev/null || echo "FAILED")

if [ "$CACHE_DB_CHECK" != "PONG" ]; then
  echo "$(date -Iseconds) ERROR: Cannot access cache database ${CACHE_DB:-1}"
  exit 1
fi

echo "$(date -Iseconds) Cache database ${CACHE_DB:-1} accessible"

# Execute cache cleanup script
CLEANUP_RESULT=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
    -a "$REDIS_PASSWORD" -n "${CACHE_DB:-1}" --eval /scripts/jobHelpers/cache-cleanup.lua \
  "${CACHE_CLEANUP_BATCH_SIZE:-200}" "${CACHE_CLEANUP_MAX_EXECUTION_TIME:-45}")

echo "$(date -Iseconds) Cache cleanup completed: $CLEANUP_RESULT"

# Parse and log results for cache cleanup
echo "$CLEANUP_RESULT" | python3 -c "
import sys
import json
import re

def parse_cleanup_results():
    try:
        content = sys.stdin.read().strip()

        # Extract Redis result format
        if content.startswith('1)') or 'expired_cleaned' in content:
            # Parse Redis array response format
            lines = content.split('\n')
            results = {}

            for line in lines:
                if 'expired_cleaned' in line:
                    results['expired_cleaned'] = int(re.search(r'(\d+)', line).group(1)) if re.search(r'(\d+)', line) else 0
                elif 'lru_cleaned' in line:
                    results['lru_cleaned'] = int(re.search(r'(\d+)', line).group(1)) if re.search(r'(\d+)', line) else 0
                elif 'total_cleaned' in line:
                    results['total_cleaned'] = int(re.search(r'(\d+)', line).group(1)) if re.search(r'(\d+)', line) else 0
                elif 'duration_ms' in line:
                    results['duration_ms'] = int(re.search(r'(\d+)', line).group(1)) if re.search(r'(\d+)', line) else 0

            print(f\"Cache cleanup completed successfully:\")
            print(f\"  - Expired entries cleaned: {results.get('expired_cleaned', 0)}\")
            print(f\"  - LRU entries cleaned: {results.get('lru_cleaned', 0)}\")
            print(f\"  - Total entries cleaned: {results.get('total_cleaned', 0)}\")
            print(f\"  - Duration: {results.get('duration_ms', 0)}ms\")
            print(f\"  - Database: 1 (cache)\")
        else:
            print(f\"Cache cleanup result: {content}\")

    except Exception as e:
        print(f\"Failed to parse cache cleanup results: {e}\")
        print(f\"Raw output: {content}\")

parse_cleanup_results()
"

echo "$(date -Iseconds) Cache cleanup job completed successfully"
