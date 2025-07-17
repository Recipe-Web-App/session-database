#!/bin/bash
# scripts/dbManagement/show-session-info.sh
# Display comprehensive session information from Redis database

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
echo "📊 Session Database Information Report"
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
echo "📈 Session Statistics"
print_separator "-"

# Create temporary file for stats script
TEMP_STATS_SCRIPT=$(mktemp)
cat > "$TEMP_STATS_SCRIPT" << 'EOF'
local session_stats_key = "session_stats"
local session_config_key = "session_config"
local cleanup_config_key = "cleanup_config"
local deletion_token_stats_key = "deletion_token_stats"
local deletion_token_config_key = "deletion_token_config"

local stats = {}

-- Get session statistics
if redis.call("EXISTS", session_stats_key) == 1 then
    local session_stats = redis.call("HGETALL", session_stats_key)
    for i = 1, #session_stats, 2 do
        stats[session_stats[i]] = session_stats[i + 1]
    end
else
    stats.error = "Session statistics not initialized"
end

-- Get session configuration
if redis.call("EXISTS", session_config_key) == 1 then
    local session_config = redis.call("HGETALL", session_config_key)
    stats.config = {}
    for i = 1, #session_config, 2 do
        stats.config[session_config[i]] = session_config[i + 1]
    end
else
    stats.config_error = "Session configuration not initialized"
end

-- Get cleanup configuration
if redis.call("EXISTS", cleanup_config_key) == 1 then
    local cleanup_config = redis.call("HGETALL", cleanup_config_key)
    stats.cleanup = {}
    for i = 1, #cleanup_config, 2 do
        stats.cleanup[cleanup_config[i]] = cleanup_config[i + 1]
    end
else
    stats.cleanup_error = "Cleanup configuration not initialized"
end

-- Get deletion token statistics
if redis.call("EXISTS", deletion_token_stats_key) == 1 then
    local deletion_stats = redis.call("HGETALL", deletion_token_stats_key)
    stats.deletion = {}
    for i = 1, #deletion_stats, 2 do
        stats.deletion[deletion_stats[i]] = deletion_stats[i + 1]
    end
else
    stats.deletion_error = "Deletion token statistics not initialized"
end
-- Get deletion token configuration
if redis.call("EXISTS", deletion_token_config_key) == 1 then
    local deletion_config = redis.call("HGETALL", deletion_token_config_key)
    stats.deletion_config = {}
    for i = 1, #deletion_config, 2 do
        stats.deletion_config[deletion_config[i]] = deletion_config[i + 1]
    end
else
    stats.deletion_config_error = "Deletion token configuration not initialized"
end

-- Get memory information
stats.memory = {
    used_memory = redis.call("INFO", "used_memory_human"),
    used_memory_peak = redis.call("INFO", "used_memory_peak_human")
}

return cjson.encode(stats)
EOF

# Copy and execute stats script
kubectl cp "$TEMP_STATS_SCRIPT" "$NAMESPACE/$POD_NAME:/tmp/stats_script.lua"

if [ -n "$REDIS_PASSWORD" ]; then
  STATS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -a "$REDIS_PASSWORD" --eval /tmp/stats_script.lua 2>/dev/null || echo "{}")
else
  STATS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli --eval /tmp/stats_script.lua 2>/dev/null || echo "{}")
fi

# Clean up temporary file
rm -f "$TEMP_STATS_SCRIPT"

# If $STATS is empty or not valid JSON, set it to '{}'
if [ -z "$STATS" ] || ! echo "$STATS" | python3 -c 'import sys, json; json.load(sys.stdin)' 2>/dev/null; then
  STATS='{}'
fi

echo "$STATS" | python3 -c "
import json
import sys

try:
    data = json.load(sys.stdin)

    print('📊 Session Statistics:')
    if 'error' not in data:
        print('  Total sessions: ' + str(data.get('total_sessions', 0)))
        print('  Active sessions: ' + str(data.get('active_sessions', 0)))
        print('  Expired sessions: ' + str(data.get('expired_sessions', 0)))
        print('  Total refresh tokens: ' + str(data.get('total_refresh_tokens', 0)))
        print('  Active refresh tokens: ' + str(data.get('active_refresh_tokens', 0)))
        print('  Expired refresh tokens: ' + str(data.get('expired_refresh_tokens', 0)))
        print('  Last cleanup: ' + str(data.get('last_cleanup', 'Never')))
    else:
        print('  ❌ ' + str(data.get('error', '')))

    print('')
    print('⚙️ Session Configuration:')
    if 'config' in data and 'config_error' not in data:
        for key, value in data['config'].items():
            print('  ' + str(key) + ': ' + str(value))
    elif 'config_error' in data:
        print('  ❌ ' + str(data.get('config_error', '')))
    else:
        print('  ⚠️ No configuration found')

    print('')
    print('🧹 Cleanup Configuration:')
    if 'cleanup' in data and 'cleanup_error' not in data:
        for key, value in data['cleanup'].items():
            print('  ' + str(key) + ': ' + str(value))
    elif 'cleanup_error' in data:
        print('  ❌ ' + str(data.get('cleanup_error', '')))
    else:
        print('  ⚠️ No cleanup configuration found')

    print('')
    print('💾 Memory Information:')
    if 'memory' in data:
        for key, value in data['memory'].items():
            print('  ' + str(key) + ': ' + str(value))

    print('')
    print('🗑️ Deletion Token Statistics:')
    if 'deletion' in data and 'deletion_error' not in data:
        for key, value in data['deletion'].items():
            print('  ' + str(key) + ': ' + str(value))
    elif 'deletion_error' in data:
        print('  ❌ ' + str(data.get('deletion_error', '')))
    else:
        print('  ⚠️ No deletion token stats found')
    print('')
    print('⚙️ Deletion Token Configuration:')
    if 'deletion_config' in data and 'deletion_config_error' not in data:
        for key, value in data['deletion_config'].items():
            print('  ' + str(key) + ': ' + str(value))
    elif 'deletion_config_error' in data:
        print('  ❌ ' + str(data.get('deletion_config_error', '')))
    else:
        print('  ⚠️ No deletion token config found')

except Exception as e:
    print('Error parsing statistics: ' + str(e))
"

print_separator "="
echo "👥 User Sessions"
print_separator "-"

# Create temporary file for users script
TEMP_USERS_SCRIPT=$(mktemp)
cat > "$TEMP_USERS_SCRIPT" << 'EOF'
local user_sessions_prefix = "user_sessions:"
local session_prefix = "session:"

local users = {}
local user_keys = redis.call("KEYS", user_sessions_prefix .. "*")

for i, user_key in ipairs(user_keys) do
    local user_id = string.sub(user_key, #user_sessions_prefix + 1)
    local session_ids = redis.call("SMEMBERS", user_key)
    local active_sessions = {}

    for j, session_id in ipairs(session_ids) do
        local session_key = session_prefix .. session_id
        if redis.call("EXISTS", session_key) == 1 then
            table.insert(active_sessions, session_id)
        else
            -- Remove expired session from user's set
            redis.call("SREM", user_key, session_id)
        end
    end

    if #active_sessions > 0 then
        users[user_id] = active_sessions
    end
end

return cjson.encode(users)
EOF

# Copy and execute users script
kubectl cp "$TEMP_USERS_SCRIPT" "$NAMESPACE/$POD_NAME:/tmp/users_script.lua"

if [ -n "$REDIS_PASSWORD" ]; then
  USERS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -a "$REDIS_PASSWORD" --eval /tmp/users_script.lua 2>/dev/null || echo "{}")
else
  USERS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli --eval /tmp/users_script.lua 2>/dev/null || echo "{}")
fi

# Clean up temporary file
rm -f "$TEMP_USERS_SCRIPT"

echo "$USERS" | python3 -c "
import json
import sys

try:
    data = json.load(sys.stdin)

    if data:
        print('Active user sessions:')
        for user_id, sessions in data.items():
            print(f'  👤 User {user_id}: {len(sessions)} sessions')
            for session_id in sessions[:5]:  # Show first 5 sessions
                print(f'    - {session_id}')
            if len(sessions) > 5:
                print(f'    ... and {len(sessions) - 5} more')
    else:
        print('  📭 No active user sessions found')

except Exception as e:
    print(f'Error parsing user sessions: {e}')
"

print_separator "="
echo "🔍 Session Details"
print_separator "-"

# Create temporary file for sessions script
TEMP_SESSIONS_SCRIPT=$(mktemp)
cat > "$TEMP_SESSIONS_SCRIPT" << 'EOF'
local session_cleanup_key = "session_cleanup"
local session_prefix = "session:"
local current_time = redis.call("TIME")[1]

local sessions = {}
local session_ids = redis.call("ZRANGE", session_cleanup_key, 0, -1)

for i, session_id in ipairs(session_ids) do
    local session_key = session_prefix .. session_id
    local session_data = redis.call("GET", session_key)

    if session_data then
        local expire_time = redis.call("ZSCORE", session_cleanup_key, session_id)
        local ttl = expire_time - current_time

        sessions[session_id] = {
            data = session_data,
            expire_time = expire_time,
            ttl = ttl,
            ttl_human = string.format('%.0f seconds', ttl)
        }
    else
        -- Remove expired session from cleanup set
        redis.call("ZREM", session_cleanup_key, session_id)
    end
end

return cjson.encode(sessions)
EOF

# Copy and execute sessions script
kubectl cp "$TEMP_SESSIONS_SCRIPT" "$NAMESPACE/$POD_NAME:/tmp/sessions_script.lua"

if [ -n "$REDIS_PASSWORD" ]; then
  SESSIONS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -a "$REDIS_PASSWORD" --eval /tmp/sessions_script.lua 2>/dev/null || echo "{}")
else
  SESSIONS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli --eval /tmp/sessions_script.lua 2>/dev/null || echo "{}")
fi

# Clean up temporary file
rm -f "$TEMP_SESSIONS_SCRIPT"

# If $SESSIONS is empty or not valid JSON, set it to '{}'
if [ -z "$SESSIONS" ] || ! echo "$SESSIONS" | python3 -c 'import sys, json; json.load(sys.stdin)' 2>/dev/null; then
  SESSIONS='{}'
fi

echo "$SESSIONS" | python3 -c "
import json
import sys

try:
    data = json.load(sys.stdin)

    if data:
        print(f'Active sessions ({len(data)}):')
        for session_id, info in list(data.items())[:10]:  # Show first 10 sessions
            print(f'  🔑 {session_id}')
            print(f'    TTL: {info[\"ttl_human\"]}')
            print(f'    Data: {info[\"data\"][:100]}{\"...\" if len(info[\"data\"]) > 100 else \"\"}')
            print('')

        if len(data) > 10:
            print(f'  ... and {len(data) - 10} more sessions')
    else:
        print('  📭 No active sessions found')

except Exception as e:
    print(f'Error parsing session details: {e}')
"

print_separator "="
echo "🧹 Cleanup Information"
print_separator "-"

# Create temporary file for cleanup script
TEMP_CLEANUP_SCRIPT=$(mktemp)
cat > "$TEMP_CLEANUP_SCRIPT" << 'EOF'
local session_cleanup_key = "session_cleanup"
local current_time = redis.call("TIME")[1]

local cleanup_info = {
    total_sessions = redis.call("ZCARD", session_cleanup_key),
    expired_sessions = redis.call("ZCOUNT", session_cleanup_key, 0, current_time),
    active_sessions = redis.call("ZCOUNT", session_cleanup_key, current_time, "+inf"),
    next_expiry = redis.call("ZRANGE", session_cleanup_key, 0, 0, "WITHSCORES")
}

if #cleanup_info.next_expiry > 0 then
    cleanup_info.next_expiry_time = cleanup_info.next_expiry[2]
    cleanup_info.next_expiry_session = cleanup_info.next_expiry[1]
    cleanup_info.seconds_until_next = cleanup_info.next_expiry_time - current_time
end

return cjson.encode(cleanup_info)
EOF

# Copy and execute cleanup script
kubectl cp "$TEMP_CLEANUP_SCRIPT" "$NAMESPACE/$POD_NAME:/tmp/cleanup_script.lua"

if [ -n "$REDIS_PASSWORD" ]; then
  CLEANUP=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -a "$REDIS_PASSWORD" --eval /tmp/cleanup_script.lua 2>/dev/null || echo "{}")
else
  CLEANUP=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli --eval /tmp/cleanup_script.lua 2>/dev/null || echo "{}")
fi

# Clean up temporary file
rm -f "$TEMP_CLEANUP_SCRIPT"

echo "$CLEANUP" | python3 -c "
import json
import sys

try:
    data = json.load(sys.stdin)

    print(f'Total tracked sessions: {data.get(\"total_sessions\", 0)}')
    print(f'Expired sessions: {data.get(\"expired_sessions\", 0)}')
    print(f'Active sessions: {data.get(\"active_sessions\", 0)}')

    if 'next_expiry_session' in data:
        print(f'Next session to expire: {data[\"next_expiry_session\"]}')
        print(f'Expires in: {data.get(\"seconds_until_next\", 0)} seconds')

except Exception as e:
    print(f'Error parsing cleanup info: {e}')
"

print_separator "="
echo "✅ Session information report completed"
print_separator "="
