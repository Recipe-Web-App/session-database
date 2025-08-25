#!/bin/bash
# scripts/dbManagement/monitor-auth.sh

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
echo "📊 Getting auth service statistics..."
print_separator "-"

# Create a temporary file for the Lua script
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'EOF'
-- Monitor OAuth2 auth service statistics
local client_prefix = "auth:client:"
local code_prefix = "auth:code:"
local access_token_prefix = "auth:access_token:"
local refresh_token_prefix = "auth:refresh_token:"
local session_prefix = "auth:session:"
local blacklist_prefix = "auth:blacklist:"
local rate_limit_prefix = "auth:rate_limit:"
local auth_stats_key = "auth_stats"
local token_cleanup_key = "auth_token_cleanup"

local stats = {}

-- Get basic auth service counts
local client_keys = redis.call("KEYS", client_prefix .. "*")
stats.total_clients = #client_keys

local code_keys = redis.call("KEYS", code_prefix .. "*")
stats.total_authorization_codes = #code_keys

local access_token_keys = redis.call("KEYS", access_token_prefix .. "*")
stats.total_access_tokens = #access_token_keys

local refresh_token_keys = redis.call("KEYS", refresh_token_prefix .. "*")
stats.total_refresh_tokens = #refresh_token_keys

local session_keys = redis.call("KEYS", session_prefix .. "*")
stats.total_auth_sessions = #session_keys

local blacklist_keys = redis.call("KEYS", blacklist_prefix .. "*")
stats.total_blacklisted_tokens = #blacklist_keys

local rate_limit_keys = redis.call("KEYS", rate_limit_prefix .. "*")
stats.total_rate_limit_entries = #rate_limit_keys

-- Get token cleanup data
local current_time = redis.call("TIME")[1]
if redis.call("EXISTS", token_cleanup_key) == 1 then
    local total_in_cleanup = redis.call("ZCARD", token_cleanup_key)
    local expired_tokens = redis.call("ZCOUNT", token_cleanup_key, 0, current_time)
    local active_tokens = redis.call("ZCOUNT", token_cleanup_key, current_time, "+inf")

    stats.total_in_cleanup = total_in_cleanup
    stats.expired_tokens = expired_tokens
    stats.active_tokens = active_tokens
else
    stats.total_in_cleanup = 0
    stats.expired_tokens = 0
    stats.active_tokens = 0
end

-- Get memory usage
stats.memory_used = redis.call("INFO", "used_memory_human")
stats.memory_peak = redis.call("INFO", "used_memory_peak_human")

-- Get client statistics
local client_stats = {}
for i, key in ipairs(client_keys) do
    local client_id = string.sub(key, #client_prefix + 1)
    local client_data = redis.call("HGET", key, "data")
    if client_data then
        -- Count tokens for this client
        local client_access_tokens = 0
        local client_refresh_tokens = 0

        for j, token_key in ipairs(access_token_keys) do
            local token_data = redis.call("HGET", token_key, "client_id")
            if token_data == client_id then
                client_access_tokens = client_access_tokens + 1
            end
        end

        for j, token_key in ipairs(refresh_token_keys) do
            local token_data = redis.call("HGET", token_key, "client_id")
            if token_data == client_id then
                client_refresh_tokens = client_refresh_tokens + 1
            end
        end

        table.insert(client_stats, {
            client_id = client_id,
            access_tokens = client_access_tokens,
            refresh_tokens = client_refresh_tokens
        })
    end
end

-- Sort by total tokens (descending)
table.sort(client_stats, function(a, b)
    return (a.access_tokens + a.refresh_tokens) > (b.access_tokens + b.refresh_tokens)
end)

-- Get top 10 clients
stats.top_clients = {}
for i = 1, math.min(10, #client_stats) do
    table.insert(stats.top_clients, client_stats[i])
end

-- Rate limiting statistics
local rate_limit_stats = {}
for i, key in ipairs(rate_limit_keys) do
    local limit_key = string.sub(key, #rate_limit_prefix + 1)
    local count = redis.call("GET", key)
    local ttl = redis.call("TTL", key)

    table.insert(rate_limit_stats, {
        key = limit_key,
        count = tonumber(count) or 0,
        ttl = tonumber(ttl) or 0
    })
end

-- Sort by count (descending)
table.sort(rate_limit_stats, function(a, b) return a.count > b.count end)

-- Get top 10 rate limited keys
stats.top_rate_limits = {}
for i = 1, math.min(10, #rate_limit_stats) do
    table.insert(stats.top_rate_limits, rate_limit_stats[i])
end

return cjson.encode(stats)
EOF

# Copy the script to the pod and execute it
kubectl cp "$TEMP_SCRIPT" "$NAMESPACE/$POD_NAME:/tmp/monitor_auth_script.lua"

if [ -n "$REDIS_PASSWORD" ]; then
  STATS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -a "$REDIS_PASSWORD" --eval /tmp/monitor_auth_script.lua 2>/dev/null || echo "{}")
else
  STATS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli --eval /tmp/monitor_auth_script.lua 2>/dev/null || echo "{}")
fi

# Clean up temporary file
rm -f "$TEMP_SCRIPT"

print_separator "="
echo "📈 Auth Service Statistics:"
print_separator "-"

echo "$STATS" | python3 -c "
import json
import sys

try:
    data = json.load(sys.stdin)

    print('🔐 OAuth2 Service Overview:')
    print(f'  Total clients: {data.get(\"total_clients\", 0)}')
    print(f'  Authorization codes: {data.get(\"total_authorization_codes\", 0)}')
    print(f'  Access tokens: {data.get(\"total_access_tokens\", 0)}')
    print(f'  Refresh tokens: {data.get(\"total_refresh_tokens\", 0)}')
    print(f'  Auth sessions: {data.get(\"total_auth_sessions\", 0)}')
    print(f'  Blacklisted tokens: {data.get(\"total_blacklisted_tokens\", 0)}')
    print(f'  Rate limit entries: {data.get(\"total_rate_limit_entries\", 0)}')
    print(f'  Tokens in cleanup: {data.get(\"total_in_cleanup\", 0)}')
    print(f'  Active tokens: {data.get(\"active_tokens\", 0)}')
    print(f'  Expired tokens: {data.get(\"expired_tokens\", 0)}')

    print('')
    print('💾 Memory Usage:')
    print(f'  Current memory: {data.get(\"memory_used\", \"unknown\")}')
    print(f'  Peak memory: {data.get(\"memory_peak\", \"unknown\")}')

    print('')
    print('👥 Top Clients by Token Count:')
    top_clients = data.get('top_clients', [])
    if top_clients:
        for i, client in enumerate(top_clients[:5], 1):
            total_tokens = client['access_tokens'] + client['refresh_tokens']
            print(f'  {i}. Client {client[\"client_id\"]}: {total_tokens} tokens ({client[\"access_tokens\"]} access, {client[\"refresh_tokens\"]} refresh)')
        if len(top_clients) > 5:
            print(f'  ... and {len(top_clients) - 5} more clients')
    else:
        print('  No active clients found')

    print('')
    print('🚦 Rate Limiting Activity:')
    top_rate_limits = data.get('top_rate_limits', [])
    if top_rate_limits:
        for i, rl in enumerate(top_rate_limits[:5], 1):
            print(f'  {i}. {rl[\"key\"]}: {rl[\"count\"]} requests (expires in {rl[\"ttl\"]}s)')
        if len(top_rate_limits) > 5:
            print(f'  ... and {len(top_rate_limits) - 5} more rate limited keys')
    else:
        print('  No active rate limits found')

except Exception as e:
    print(f'Error parsing statistics: {e}')
    print('Raw data:', sys.stdin.read())
"

print_separator "="
echo "✅ Auth service monitoring completed."
print_separator "="
