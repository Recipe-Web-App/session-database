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
echo "🔍 Testing Redis connection..."
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
echo "📊 Getting session statistics..."
print_separator "-"

# Create a temporary file for the Lua script
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'EOF'
-- Monitor session statistics
local session_prefix = "session:"
local user_sessions_prefix = "user_sessions:"
local session_cleanup_key = "session_cleanup"
local session_stats_key = "session_stats"
local refresh_token_prefix = "refresh_token:"
local user_refresh_tokens_prefix = "user_refresh_tokens:"
local refresh_token_cleanup_key = "refresh_token_cleanup"

local stats = {}

-- Get basic session counts
local session_keys = redis.call("KEYS", session_prefix .. "*")
stats.total_sessions = #session_keys

-- Get refresh token counts
local refresh_token_keys = redis.call("KEYS", refresh_token_prefix .. "*")
stats.total_refresh_tokens = #refresh_token_keys

-- Get user session counts
local user_session_keys = redis.call("KEYS", user_sessions_prefix .. "*")
stats.total_users_with_sessions = #user_session_keys

-- Get user refresh token counts
local user_refresh_token_keys = redis.call("KEYS", user_refresh_tokens_prefix .. "*")
stats.total_users_with_refresh_tokens = #user_refresh_token_keys

-- Get cleanup data
local total_in_cleanup = redis.call("ZCARD", session_cleanup_key)
local current_time = redis.call("TIME")[1]
local active_sessions = redis.call("ZCOUNT", session_cleanup_key, current_time, "+inf")
local expired_sessions = redis.call("ZCOUNT", session_cleanup_key, 0, current_time)

-- Get refresh token cleanup data
local total_refresh_tokens_in_cleanup = redis.call("ZCARD", refresh_token_cleanup_key)
local active_refresh_tokens = redis.call("ZCOUNT", refresh_token_cleanup_key, current_time, "+inf")
local expired_refresh_tokens = redis.call("ZCOUNT", refresh_token_cleanup_key, 0, current_time)

stats.total_in_cleanup = total_in_cleanup
stats.active_sessions = active_sessions
stats.expired_sessions = expired_sessions
stats.total_refresh_tokens_in_cleanup = total_refresh_tokens_in_cleanup
stats.active_refresh_tokens = active_refresh_tokens
stats.expired_refresh_tokens = expired_refresh_tokens

-- Get memory usage
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

# Copy the script to the pod and execute it
kubectl cp "$TEMP_SCRIPT" "$NAMESPACE/$POD_NAME:/tmp/monitor_script.lua"

if [ -n "$REDIS_PASSWORD" ]; then
  STATS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -a "$REDIS_PASSWORD" --eval /tmp/monitor_script.lua 2>/dev/null || echo "{}")
else
  STATS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli --eval /tmp/monitor_script.lua 2>/dev/null || echo "{}")
fi

# Clean up temporary file
rm -f "$TEMP_SCRIPT"

print_separator "="
echo "📈 Session Statistics:"
print_separator "-"

echo "$STATS" | python3 -c "
import json
import sys

try:
    data = json.load(sys.stdin)

    print('📊 Session Overview:')
    print(f'  Total sessions: {data.get(\"total_sessions\", 0)}')
    print(f'  Total refresh tokens: {data.get(\"total_refresh_tokens\", 0)}')
    print(f'  Users with sessions: {data.get(\"total_users_with_sessions\", 0)}')
    print(f'  Users with refresh tokens: {data.get(\"total_users_with_refresh_tokens\", 0)}')
    print(f'  Sessions in cleanup: {data.get(\"total_in_cleanup\", 0)}')
    print(f'  Refresh tokens in cleanup: {data.get(\"total_refresh_tokens_in_cleanup\", 0)}')
    print(f'  Active sessions: {data.get(\"active_sessions\", 0)}')
    print(f'  Active refresh tokens: {data.get(\"active_refresh_tokens\", 0)}')
    print(f'  Expired sessions: {data.get(\"expired_sessions\", 0)}')
    print(f'  Expired refresh tokens: {data.get(\"expired_refresh_tokens\", 0)}')

    print('')
    print('💾 Memory Usage:')
    print(f'  Current memory: {data.get(\"memory_used\", \"unknown\")}')
    print(f'  Peak memory: {data.get(\"memory_peak\", \"unknown\")}')

    print('')
    print('👥 Top Users by Session Count:')
    top_users = data.get('top_users', [])
    if top_users:
        for i, user in enumerate(top_users[:5], 1):
            print(f'  {i}. User {user[\"user_id\"]}: {user[\"sessions\"]} sessions')
        if len(top_users) > 5:
            print(f'  ... and {len(top_users) - 5} more users')
    else:
        print('  No active users found')

except Exception as e:
    print(f'Error parsing statistics: {e}')
    print('Raw data:', sys.stdin.read())
"

print_separator "="
echo "✅ Session monitoring completed."
print_separator "="
