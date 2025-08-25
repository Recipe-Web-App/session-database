#!/bin/bash
# scripts/dbManagement/show-auth-info.sh
# Display comprehensive auth service information from Redis database

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
echo "📊 Auth Service Database Information Report"
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
echo "📈 Auth Service Configuration & Statistics"
print_separator "-"

# Create temporary file for stats script
TEMP_STATS_SCRIPT=$(mktemp)
cat > "$TEMP_STATS_SCRIPT" << 'EOF'
local auth_stats_key = "auth_stats"
local auth_config_key = "auth_config"
local rate_limit_config_key = "auth:rate_limit_config"

local stats = {}

-- Get auth statistics
if redis.call("EXISTS", auth_stats_key) == 1 then
    local auth_stats = redis.call("HGETALL", auth_stats_key)
    for i = 1, #auth_stats, 2 do
        stats[auth_stats[i]] = auth_stats[i + 1]
    end
else
    stats.error = "Auth statistics not initialized"
end

-- Get auth configuration
if redis.call("EXISTS", auth_config_key) == 1 then
    local auth_config = redis.call("HGETALL", auth_config_key)
    stats.config = {}
    for i = 1, #auth_config, 2 do
        stats.config[auth_config[i]] = auth_config[i + 1]
    end
else
    stats.config_error = "Auth configuration not initialized"
end

-- Get rate limit configuration
if redis.call("EXISTS", rate_limit_config_key) == 1 then
    local rate_limit_config = redis.call("HGETALL", rate_limit_config_key)
    stats.rate_limit_config = {}
    for i = 1, #rate_limit_config, 2 do
        stats.rate_limit_config[rate_limit_config[i]] = rate_limit_config[i + 1]
    end
else
    stats.rate_limit_config_error = "Rate limit configuration not initialized"
end

-- Get memory information
stats.memory = {
    used_memory = redis.call("INFO", "used_memory_human"),
    used_memory_peak = redis.call("INFO", "used_memory_peak_human")
}

return cjson.encode(stats)
EOF

# Copy and execute stats script
kubectl cp "$TEMP_STATS_SCRIPT" "$NAMESPACE/$POD_NAME:/tmp/auth_stats_script.lua"

if [ -n "$REDIS_PASSWORD" ]; then
  STATS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -a "$REDIS_PASSWORD" --eval /tmp/auth_stats_script.lua 2>/dev/null || echo "{}")
else
  STATS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli --eval /tmp/auth_stats_script.lua 2>/dev/null || echo "{}")
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

    print('📊 Auth Service Statistics:')
    if 'error' not in data:
        print('  Total clients: ' + str(data.get('total_clients', 0)))
        print('  Active clients: ' + str(data.get('active_clients', 0)))
        print('  Authorization codes: ' + str(data.get('total_authorization_codes', 0)))
        print('  Active authorization codes: ' + str(data.get('active_authorization_codes', 0)))
        print('  Expired authorization codes: ' + str(data.get('expired_authorization_codes', 0)))
        print('  Access tokens: ' + str(data.get('total_access_tokens', 0)))
        print('  Active access tokens: ' + str(data.get('active_access_tokens', 0)))
        print('  Expired access tokens: ' + str(data.get('expired_access_tokens', 0)))
        print('  Revoked access tokens: ' + str(data.get('revoked_access_tokens', 0)))
        print('  Refresh tokens: ' + str(data.get('total_refresh_tokens', 0)))
        print('  Active refresh tokens: ' + str(data.get('active_refresh_tokens', 0)))
        print('  Expired refresh tokens: ' + str(data.get('expired_refresh_tokens', 0)))
        print('  Revoked refresh tokens: ' + str(data.get('revoked_refresh_tokens', 0)))
        print('  Auth sessions: ' + str(data.get('total_sessions', 0)))
        print('  Active auth sessions: ' + str(data.get('active_sessions', 0)))
        print('  Expired auth sessions: ' + str(data.get('expired_sessions', 0)))
        print('  Blacklisted tokens: ' + str(data.get('blacklisted_tokens', 0)))
        print('  Rate limited requests: ' + str(data.get('rate_limited_requests', 0)))
        print('  Last cleanup: ' + str(data.get('last_cleanup', 'Never')))
    else:
        print('  ❌ ' + str(data.get('error', '')))

    print('')
    print('⚙️ Auth Service Configuration:')
    if 'config' in data and 'config_error' not in data:
        for key, value in data['config'].items():
            print('  ' + str(key) + ': ' + str(value))
    elif 'config_error' in data:
        print('  ❌ ' + str(data.get('config_error', '')))
    else:
        print('  ⚠️ No configuration found')

    print('')
    print('🚦 Rate Limiting Configuration:')
    if 'rate_limit_config' in data and 'rate_limit_config_error' not in data:
        for key, value in data['rate_limit_config'].items():
            print('  ' + str(key) + ': ' + str(value))
    elif 'rate_limit_config_error' in data:
        print('  ❌ ' + str(data.get('rate_limit_config_error', '')))
    else:
        print('  ⚠️ No rate limit configuration found')

    print('')
    print('💾 Memory Information:')
    if 'memory' in data:
        for key, value in data['memory'].items():
            print('  ' + str(key) + ': ' + str(value))

except Exception as e:
    print('Error parsing statistics: ' + str(e))
"

print_separator "="
echo "👥 OAuth2 Clients"
print_separator "-"

# Create temporary file for clients script
TEMP_CLIENTS_SCRIPT=$(mktemp)
cat > "$TEMP_CLIENTS_SCRIPT" << 'EOF'
local client_prefix = "auth:client:"

local clients = {}
local client_keys = redis.call("KEYS", client_prefix .. "*")

for i, client_key in ipairs(client_keys) do
    local client_id = string.sub(client_key, #client_prefix + 1)
    local client_data = redis.call("HGETALL", client_key)

    if #client_data > 0 then
        local client_info = {}
        for j = 1, #client_data, 2 do
            client_info[client_data[j]] = client_data[j + 1]
        end
        clients[client_id] = client_info
    end
end

return cjson.encode(clients)
EOF

# Copy and execute clients script
kubectl cp "$TEMP_CLIENTS_SCRIPT" "$NAMESPACE/$POD_NAME:/tmp/auth_clients_script.lua"

if [ -n "$REDIS_PASSWORD" ]; then
  CLIENTS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -a "$REDIS_PASSWORD" --eval /tmp/auth_clients_script.lua 2>/dev/null || echo "{}")
else
  CLIENTS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli --eval /tmp/auth_clients_script.lua 2>/dev/null || echo "{}")
fi

# Clean up temporary file
rm -f "$TEMP_CLIENTS_SCRIPT"

echo "$CLIENTS" | python3 -c "
import json
import sys

try:
    data = json.load(sys.stdin)

    if data:
        print('Registered OAuth2 clients:')
        for client_id, client_info in data.items():
            print(f'  🔑 Client: {client_id}')
            for key, value in client_info.items():
                if key == 'secret':
                    print(f'    {key}: [REDACTED]')
                elif key == 'data':
                    # Try to parse JSON data
                    try:
                        client_data = json.loads(value)
                        print(f'    redirect_uris: {client_data.get(\"redirect_uris\", [])}')
                        print(f'    scopes: {client_data.get(\"scopes\", [])}')
                        print(f'    grant_types: {client_data.get(\"grant_types\", [])}')
                    except:
                        print(f'    {key}: [JSON data]')
                else:
                    print(f'    {key}: {value}')
            print('')
    else:
        print('  📭 No OAuth2 clients found')

except Exception as e:
    print(f'Error parsing clients: {e}')
"

print_separator "="
echo "🔍 Token Details"
print_separator "-"

# Create temporary file for tokens script
TEMP_TOKENS_SCRIPT=$(mktemp)
cat > "$TEMP_TOKENS_SCRIPT" << 'EOF'
local access_token_prefix = "auth:access_token:"
local refresh_token_prefix = "auth:refresh_token:"
local code_prefix = "auth:code:"
local session_prefix = "auth:session:"
local blacklist_prefix = "auth:blacklist:"

local tokens = {
    access_tokens = {},
    refresh_tokens = {},
    authorization_codes = {},
    auth_sessions = {},
    blacklisted_tokens = {}
}

-- Get access tokens (limit to 10)
local access_token_keys = redis.call("KEYS", access_token_prefix .. "*")
for i = 1, math.min(10, #access_token_keys) do
    local token_key = access_token_keys[i]
    local token_id = string.sub(token_key, #access_token_prefix + 1)
    local token_data = redis.call("HGETALL", token_key)

    if #token_data > 0 then
        local token_info = {token_id = token_id}
        for j = 1, #token_data, 2 do
            token_info[token_data[j]] = token_data[j + 1]
        end
        local ttl = redis.call("TTL", token_key)
        token_info.ttl = ttl
        table.insert(tokens.access_tokens, token_info)
    end
end

-- Get refresh tokens (limit to 10)
local refresh_token_keys = redis.call("KEYS", refresh_token_prefix .. "*")
for i = 1, math.min(10, #refresh_token_keys) do
    local token_key = refresh_token_keys[i]
    local token_id = string.sub(token_key, #refresh_token_prefix + 1)
    local token_data = redis.call("HGETALL", token_key)

    if #token_data > 0 then
        local token_info = {token_id = token_id}
        for j = 1, #token_data, 2 do
            token_info[token_data[j]] = token_data[j + 1]
        end
        local ttl = redis.call("TTL", token_key)
        token_info.ttl = ttl
        table.insert(tokens.refresh_tokens, token_info)
    end
end

-- Get authorization codes (limit to 5)
local code_keys = redis.call("KEYS", code_prefix .. "*")
for i = 1, math.min(5, #code_keys) do
    local code_key = code_keys[i]
    local code_id = string.sub(code_key, #code_prefix + 1)
    local code_data = redis.call("HGETALL", code_key)

    if #code_data > 0 then
        local code_info = {code_id = code_id}
        for j = 1, #code_data, 2 do
            code_info[code_data[j]] = code_data[j + 1]
        end
        local ttl = redis.call("TTL", code_key)
        code_info.ttl = ttl
        table.insert(tokens.authorization_codes, code_info)
    end
end

-- Get auth sessions (limit to 5)
local session_keys = redis.call("KEYS", session_prefix .. "*")
for i = 1, math.min(5, #session_keys) do
    local session_key = session_keys[i]
    local session_id = string.sub(session_key, #session_prefix + 1)
    local session_data = redis.call("HGETALL", session_key)

    if #session_data > 0 then
        local session_info = {session_id = session_id}
        for j = 1, #session_data, 2 do
            session_info[session_data[j]] = session_data[j + 1]
        end
        local ttl = redis.call("TTL", session_key)
        session_info.ttl = ttl
        table.insert(tokens.auth_sessions, session_info)
    end
end

-- Get blacklisted tokens (limit to 10)
local blacklist_keys = redis.call("KEYS", blacklist_prefix .. "*")
for i = 1, math.min(10, #blacklist_keys) do
    local blacklist_key = blacklist_keys[i]
    local token_id = string.sub(blacklist_key, #blacklist_prefix + 1)
    local blacklist_data = redis.call("GET", blacklist_key)
    local ttl = redis.call("TTL", blacklist_key)

    table.insert(tokens.blacklisted_tokens, {
        token_id = token_id,
        status = blacklist_data,
        ttl = ttl
    })
end

tokens.total_counts = {
    access_tokens = #access_token_keys,
    refresh_tokens = #refresh_token_keys,
    authorization_codes = #code_keys,
    auth_sessions = #session_keys,
    blacklisted_tokens = #blacklist_keys
}

return cjson.encode(tokens)
EOF

# Copy and execute tokens script
kubectl cp "$TEMP_TOKENS_SCRIPT" "$NAMESPACE/$POD_NAME:/tmp/auth_tokens_script.lua"

if [ -n "$REDIS_PASSWORD" ]; then
  TOKENS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -a "$REDIS_PASSWORD" --eval /tmp/auth_tokens_script.lua 2>/dev/null || echo "{}")
else
  TOKENS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli --eval /tmp/auth_tokens_script.lua 2>/dev/null || echo "{}")
fi

# Clean up temporary file
rm -f "$TEMP_TOKENS_SCRIPT"

# If $TOKENS is empty or not valid JSON, set it to '{}'
if [ -z "$TOKENS" ] || ! echo "$TOKENS" | python3 -c 'import sys, json; json.load(sys.stdin)' 2>/dev/null; then
  TOKENS='{}'
fi

echo "$TOKENS" | python3 -c "
import json
import sys

def mask_token(token_id):
    if len(token_id) > 10:
        return token_id[:3] + '***' + token_id[-4:]
    return token_id

try:
    data = json.load(sys.stdin)

    if 'total_counts' in data:
        counts = data['total_counts']
        print(f'Token Overview (showing samples):')
        print(f'  Access tokens: {counts[\"access_tokens\"]} total')
        print(f'  Refresh tokens: {counts[\"refresh_tokens\"]} total')
        print(f'  Authorization codes: {counts[\"authorization_codes\"]} total')
        print(f'  Auth sessions: {counts[\"auth_sessions\"]} total')
        print(f'  Blacklisted tokens: {counts[\"blacklisted_tokens\"]} total')
        print('')

    # Access Tokens
    access_tokens = data.get('access_tokens', [])
    if access_tokens:
        print('🔐 Access Tokens (sample):')
        for token in access_tokens[:5]:
            print(f'  Token: {mask_token(token[\"token_id\"])}')
            print(f'    Client: {token.get(\"client_id\", \"unknown\")}')
            print(f'    User: {token.get(\"user_id\", \"unknown\")}')
            print(f'    Scope: {token.get(\"scope\", \"unknown\")}')
            print(f'    TTL: {token.get(\"ttl\", \"unknown\")} seconds')
            print(f'    Status: {token.get(\"revoked\", \"false\")}')
            print('')

    # Refresh Tokens
    refresh_tokens = data.get('refresh_tokens', [])
    if refresh_tokens:
        print('🔄 Refresh Tokens (sample):')
        for token in refresh_tokens[:5]:
            print(f'  Token: {mask_token(token[\"token_id\"])}')
            print(f'    Client: {token.get(\"client_id\", \"unknown\")}')
            print(f'    User: {token.get(\"user_id\", \"unknown\")}')
            print(f'    TTL: {token.get(\"ttl\", \"unknown\")} seconds')
            print('')

    # Authorization Codes
    auth_codes = data.get('authorization_codes', [])
    if auth_codes:
        print('📋 Authorization Codes (sample):')
        for code in auth_codes[:3]:
            print(f'  Code: {mask_token(code[\"code_id\"])}')
            print(f'    Client: {code.get(\"client_id\", \"unknown\")}')
            print(f'    User: {code.get(\"user_id\", \"unknown\")}')
            print(f'    TTL: {code.get(\"ttl\", \"unknown\")} seconds')
            print('')

    # Blacklisted Tokens
    blacklisted = data.get('blacklisted_tokens', [])
    if blacklisted:
        print('🚫 Blacklisted Tokens (sample):')
        for token in blacklisted[:5]:
            print(f'  Token: {mask_token(token[\"token_id\"])}')
            print(f'    Status: {token.get(\"status\", \"unknown\")}')
            print(f'    TTL: {token.get(\"ttl\", \"unknown\")} seconds')
            print('')

    if not any([access_tokens, refresh_tokens, auth_codes, blacklisted]):
        print('  📭 No tokens found')

except Exception as e:
    print(f'Error parsing token details: {e}')
"

print_separator "="
echo "✅ Auth service information report completed"
print_separator "="
