#!/bin/bash
# scripts/jobHelpers/session-health-check.sh

set -euo pipefail

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

NAMESPACE="session-database"
POD_LABEL="app=session-database"

print_separator "="
echo "🏥 Running session health check..."
print_separator "-"

# Load environment variables
if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -o allexport
  # shellcheck source=.env
  source .env
  set +o allexport
fi

REDIS_PASSWORD=${REDIS_PASSWORD:-}

# Find Redis pod
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "$POD_LABEL" \
    --field-selector=status.phase=Running \
  -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)

if [ -z "$POD_NAME" ]; then
  echo "❌ No running Redis pod found"
  exit 1
fi

print_separator "="
echo "🔍 Checking Redis connection..."
print_separator "-"

# Test Redis connection
if [ -n "$REDIS_PASSWORD" ]; then
  PING_RESULT=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -a "$REDIS_PASSWORD" ping 2>/dev/null || echo "FAILED")
else
  PING_RESULT=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli ping 2>/dev/null || echo "FAILED")
fi

if [ "$PING_RESULT" = "PONG" ]; then
  echo "✅ Redis connection: OK"
else
  echo "❌ Redis connection: FAILED"
  exit 1
fi

print_separator "="
echo "📊 Checking session statistics..."
print_separator "-"

# Get session stats
STATS_SCRIPT=$(cat << 'EOF'
local session_cleanup_key = "session_cleanup"
local session_stats_key = "session_stats"

local stats = {}

-- Get basic counts
local total_sessions = redis.call("ZCARD", session_cleanup_key)
local current_time = redis.call("TIME")[1]
local active_sessions = redis.call("ZCOUNT", session_cleanup_key, current_time, "+inf")
local expired_sessions = redis.call("ZCOUNT", session_cleanup_key, 0, current_time)

stats.total_sessions = total_sessions
stats.active_sessions = active_sessions
stats.expired_sessions = expired_sessions

-- Get memory usage
stats.memory_used = redis.call("INFO", "used_memory_human")
stats.memory_peak = redis.call("INFO", "used_memory_peak_human")

return cjson.encode(stats)
EOF
)

if [ -n "$REDIS_PASSWORD" ]; then
  STATS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -a "$REDIS_PASSWORD" --eval <(echo "$STATS_SCRIPT") 2>/dev/null || echo "{}")
else
  STATS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli --eval <(echo "$STATS_SCRIPT") 2>/dev/null || echo "{}")
fi

echo "$STATS" | python3 -c "
import json
import sys

try:
    data = json.load(sys.stdin)
    print(f'Total sessions: {data.get(\"total_sessions\", 0)}')
    print(f'Active sessions: {data.get(\"active_sessions\", 0)}')
    print(f'Expired sessions: {data.get(\"expired_sessions\", 0)}')
    print(f'Memory used: {data.get(\"memory_used\", \"unknown\")}')
    print(f'Memory peak: {data.get(\"memory_peak\", \"unknown\")}')
except Exception as e:
    print(f'Error parsing stats: {e}')
"

print_separator "="
echo "🧹 Running cleanup check..."
print_separator "-"

# Check for expired sessions
CLEANUP_SCRIPT=$(cat << 'EOF'
local session_cleanup_key = "session_cleanup"
local current_time = redis.call("TIME")[1]
local expired_count = redis.call("ZCOUNT", session_cleanup_key, 0, current_time)

if expired_count > 0 then
    print("Found " .. expired_count .. " expired sessions")
    return expired_count
else
    print("No expired sessions found")
    return 0
end
EOF
)

if [ -n "$REDIS_PASSWORD" ]; then
  EXPIRED_COUNT=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -a "$REDIS_PASSWORD" --eval <(echo "$CLEANUP_SCRIPT") 2>/dev/null || echo "0")
else
  EXPIRED_COUNT=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli --eval <(echo "$CLEANUP_SCRIPT") 2>/dev/null || echo "0")
fi

if [ "$EXPIRED_COUNT" -gt 0 ]; then
  echo "⚠️  Found $EXPIRED_COUNT expired sessions"
else
  echo "✅ No expired sessions found"
fi

print_separator "="
echo "✅ Health check completed successfully."
print_separator "="
