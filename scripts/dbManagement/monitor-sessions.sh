#!/bin/bash
# scripts/dbManagement/monitor-sessions.sh

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
echo "📥 Loading environment variables..."
print_separator "-"

if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -o allexport
  # shellcheck source=.env
  source .env
  set +o allexport
  echo "✅ Environment variables loaded."
else
  echo "ℹ️ No .env file found. Proceeding without loading environment variables."
fi

REDIS_PASSWORD=${REDIS_PASSWORD:-}

print_separator "="
echo "🚀 Finding a running Redis pod in namespace $NAMESPACE..."
print_separator "-"

POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "$POD_LABEL" \
    --field-selector=status.phase=Running \
  -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)

if [ -z "$POD_NAME" ]; then
  echo "❌ No running Redis pod found in namespace $NAMESPACE with label $POD_LABEL"
  echo "   (Tip: Check 'kubectl get pods -n $NAMESPACE' to see pod status.)"
  exit 1
fi

echo "✅ Found pod: $POD_NAME"

print_separator "="
echo "📊 Getting session statistics..."
print_separator "-"

# Create monitoring script
MONITOR_SCRIPT=$(cat << 'EOF'
-- Monitor session statistics
local session_prefix = "session:"
local user_sessions_prefix = "user_sessions:"
local session_cleanup_key = "session_cleanup"
local session_stats_key = "session_stats"

local stats = {}

-- Get basic session counts
local session_keys = redis.call("KEYS", session_prefix .. "*")
stats.total_sessions = #session_keys

-- Get user session counts
local user_session_keys = redis.call("KEYS", user_sessions_prefix .. "*")
stats.total_users_with_sessions = #user_session_keys

-- Get cleanup data
local total_in_cleanup = redis.call("ZCARD", session_cleanup_key)
local current_time = redis.call("TIME")[1]
local active_sessions = redis.call("ZCOUNT", session_cleanup_key, current_time, "+inf")
local expired_sessions = redis.call("ZCOUNT", session_cleanup_key, 0, current_time)

stats.total_in_cleanup = total_in_cleanup
stats.active_sessions = active_sessions
stats.expired_sessions = expired_sessions

-- Get memory usage
local memory_info = redis.call("INFO", "memory")
stats.memory_used = redis.call("INFO", "used_memory_human")
stats.memory_peak = redis.call("INFO", "used_memory_peak_human")

-- Get top users by session count
local top_users = {}
for i, key in ipairs(user_session_keys) do
    local user_id = string.sub(key, #user_sessions_prefix + 1)
    local session_count = redis.call("SCARD", key)
    if session_count > 0 then
        table.insert(top_users, {user_id = user_id, sessions = session_count})
    end
end

-- Sort by session count (descending)
table.sort(top_users, function(a, b) return a.sessions > b.sessions end)

-- Get top 10 users
stats.top_users = {}
for i = 1, math.min(10, #top_users) do
    table.insert(stats.top_users, top_users[i])
end

return cjson.encode(stats)
EOF
)

if [ -n "$REDIS_PASSWORD" ]; then
  STATS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -a "$REDIS_PASSWORD" --eval <(echo "$MONITOR_SCRIPT"))
else
  STATS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli --eval <(echo "$MONITOR_SCRIPT"))
fi

print_separator "="
echo "📈 Session Statistics:"
print_separator "-"

echo "$STATS" | python3 -m json.tool

print_separator "="
echo "✅ Session monitoring completed."
print_separator "="
