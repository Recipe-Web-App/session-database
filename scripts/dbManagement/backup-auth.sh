#!/bin/bash
# scripts/dbManagement/backup-auth.sh

set -euo pipefail

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

NAMESPACE="redis-database"
POD_LABEL="app=redis-database"
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DATABASE=${1:-"all"}  # Default to backing up all databases

# Validate database selection
case "$DATABASE" in
  "all"|"auth"|"cache"|"0"|"1")
    # Valid options
    ;;
  *)
    echo "❌ Invalid database option: $DATABASE"
    echo "   Usage: $0 [all|auth|cache|0|1]"
    echo "   Examples:"
    echo "     $0           # Backup all databases (default)"
    echo "     $0 all       # Backup all databases"
    echo "     $0 auth      # Backup only auth database (DB 0)"
    echo "     $0 cache     # Backup only cache database (DB 1)"
    echo "     $0 0         # Backup only auth database (DB 0)"
    echo "     $0 1         # Backup only cache database (DB 1)"
    exit 1
    ;;
esac

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
echo "📦 Creating backup directory..."
print_separator "-"

mkdir -p "$BACKUP_DIR"

# Determine which databases to backup
BACKUP_AUTH=false
BACKUP_CACHE=false

case "$DATABASE" in
  "all")
    BACKUP_AUTH=true
    BACKUP_CACHE=true
    BACKUP_FILE="$BACKUP_DIR/full_backup_$TIMESTAMP.json"
    ;;
  "auth"|"0")
    BACKUP_AUTH=true
    BACKUP_FILE="$BACKUP_DIR/auth_backup_$TIMESTAMP.json"
    ;;
  "cache"|"1")
    BACKUP_CACHE=true
    BACKUP_FILE="$BACKUP_DIR/cache_backup_$TIMESTAMP.json"
    ;;
esac

print_separator "="
echo "💾 Starting backup for: $DATABASE"
[ "$BACKUP_AUTH" = true ] && echo "   - Auth database (DB 0)"
[ "$BACKUP_CACHE" = true ] && echo "   - Cache database (DB 1)"
print_separator "-"

# Create backup data structure
echo "{" > "$BACKUP_FILE"
echo "  \"timestamp\": \"$TIMESTAMP\"," >> "$BACKUP_FILE"
echo "  \"databases\": {" >> "$BACKUP_FILE"

# Function to backup auth database (DB 0)
backup_auth() {
  echo "    \"auth\": {" >> "$BACKUP_FILE"
  echo "      \"database\": 0," >> "$BACKUP_FILE"

  # Create Lua script for auth backup
  TEMP_SCRIPT=$(mktemp)
  cat > "$TEMP_SCRIPT" << 'EOF'
-- Switch to auth database
redis.call("SELECT", 0)

local client_prefix = "auth:client:"
local code_prefix = "auth:code:"
local access_token_prefix = "auth:access_token:"
local refresh_token_prefix = "auth:refresh_token:"
local session_prefix = "auth:session:"
local blacklist_prefix = "auth:blacklist:"
local rate_limit_prefix = "auth:rate_limit:"
local auth_stats_key = "auth_stats"
local auth_config_key = "auth_config"
local token_cleanup_key = "auth_token_cleanup"

local backup_data = {}

-- Get OAuth2 clients
local client_keys = redis.call("KEYS", client_prefix .. "*")
backup_data.clients = {}
for i, key in ipairs(client_keys) do
    local client_data = redis.call("HGETALL", key)
    if #client_data > 0 then
        local client_id = string.sub(key, #client_prefix + 1)
        backup_data.clients[client_id] = client_data
    end
end

-- Get authorization codes
local code_keys = redis.call("KEYS", code_prefix .. "*")
backup_data.authorization_codes = {}
for i, key in ipairs(code_keys) do
    local code_data = redis.call("HGETALL", key)
    local ttl = redis.call("TTL", key)
    if #code_data > 0 then
        local code_id = string.sub(key, #code_prefix + 1)
        backup_data.authorization_codes[code_id] = {
            data = code_data,
            ttl = ttl
        }
    end
end

-- Get access tokens
local access_token_keys = redis.call("KEYS", access_token_prefix .. "*")
backup_data.access_tokens = {}
for i, key in ipairs(access_token_keys) do
    local token_data = redis.call("HGETALL", key)
    local ttl = redis.call("TTL", key)
    if #token_data > 0 then
        local token_id = string.sub(key, #access_token_prefix + 1)
        backup_data.access_tokens[token_id] = {
            data = token_data,
            ttl = ttl
        }
    end
end

-- Get refresh tokens
local refresh_token_keys = redis.call("KEYS", refresh_token_prefix .. "*")
backup_data.refresh_tokens = {}
for i, key in ipairs(refresh_token_keys) do
    local token_data = redis.call("HGETALL", key)
    local ttl = redis.call("TTL", key)
    if #token_data > 0 then
        local token_id = string.sub(key, #refresh_token_prefix + 1)
        backup_data.refresh_tokens[token_id] = {
            data = token_data,
            ttl = ttl
        }
    end
end

-- Get auth sessions
local session_keys = redis.call("KEYS", session_prefix .. "*")
backup_data.auth_sessions = {}
for i, key in ipairs(session_keys) do
    local session_data = redis.call("HGETALL", key)
    local ttl = redis.call("TTL", key)
    if #session_data > 0 then
        local session_id = string.sub(key, #session_prefix + 1)
        backup_data.auth_sessions[session_id] = {
            data = session_data,
            ttl = ttl
        }
    end
end

-- Get blacklisted tokens
local blacklist_keys = redis.call("KEYS", blacklist_prefix .. "*")
backup_data.blacklisted_tokens = {}
for i, key in ipairs(blacklist_keys) do
    local blacklist_data = redis.call("GET", key)
    local ttl = redis.call("TTL", key)
    local token_id = string.sub(key, #blacklist_prefix + 1)
    backup_data.blacklisted_tokens[token_id] = {
        status = blacklist_data,
        ttl = ttl
    }
end

-- Get rate limit entries
local rate_limit_keys = redis.call("KEYS", rate_limit_prefix .. "*")
backup_data.rate_limits = {}
for i, key in ipairs(rate_limit_keys) do
    local count = redis.call("GET", key)
    local ttl = redis.call("TTL", key)
    local limit_key = string.sub(key, #rate_limit_prefix + 1)
    backup_data.rate_limits[limit_key] = {
        count = count,
        ttl = ttl
    }
end

-- Get cleanup data
backup_data.token_cleanup = redis.call("ZRANGE", token_cleanup_key, 0, -1, "WITHSCORES")

-- Get statistics and configuration
backup_data.auth_stats = redis.call("HGETALL", auth_stats_key)
backup_data.auth_config = redis.call("HGETALL", auth_config_key)
backup_data.rate_limit_config = redis.call("HGETALL", "auth:rate_limit_config")

return cjson.encode(backup_data)
EOF

  kubectl cp "$TEMP_SCRIPT" "$NAMESPACE/$POD_NAME:/tmp/auth_backup.lua"

  if [ -n "$REDIS_PASSWORD" ]; then
    AUTH_DATA=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
      redis-cli -a "$REDIS_PASSWORD" --eval /tmp/auth_backup.lua 2>/dev/null || echo "{}")
  else
    AUTH_DATA=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
      redis-cli --eval /tmp/auth_backup.lua 2>/dev/null || echo "{}")
  fi

  echo "      \"data\": $AUTH_DATA" >> "$BACKUP_FILE"
  echo "    }" >> "$BACKUP_FILE"

  rm -f "$TEMP_SCRIPT"
}

# Function to backup cache database (DB 1)
backup_cache() {
  echo "    \"cache\": {" >> "$BACKUP_FILE"
  echo "      \"database\": 1," >> "$BACKUP_FILE"

  # Create Lua script for cache backup
  TEMP_SCRIPT=$(mktemp)
  cat > "$TEMP_SCRIPT" << 'EOF'
-- Switch to cache database
redis.call("SELECT", 1)

local cache_types = {"user_profile", "api_response", "computation", "resource"}
local backup_data = {}

-- Get cache entries by type
backup_data.cache_entries = {}
for _, cache_type in ipairs(cache_types) do
    local pattern = "cache:" .. cache_type .. ":*"
    local cache_keys = redis.call("KEYS", pattern)
    backup_data.cache_entries[cache_type] = {}

    for i, key in ipairs(cache_keys) do
        local cache_data = redis.call("HGETALL", key)
        local ttl = redis.call("TTL", key)
        if #cache_data > 0 then
            local cache_id = string.sub(key, #pattern - 1)
            backup_data.cache_entries[cache_type][cache_id] = {
                data = cache_data,
                ttl = ttl
            }
        end
    end
end

-- Get cache statistics
backup_data.cache_stats = redis.call("HGETALL", "cache_stats")
backup_data.cache_config = redis.call("HGETALL", "cache_config")
backup_data.cache_cleanup_metrics = redis.call("HGETALL", "cache_cleanup_metrics")

-- Get cache cleanup data
backup_data.cache_cleanup = redis.call("ZRANGE", "cache_cleanup", 0, -1, "WITHSCORES")

-- Get service-specific stats
for _, cache_type in ipairs(cache_types) do
    local stats_key = "cache_stats:" .. cache_type
    backup_data["cache_stats_" .. cache_type] = redis.call("HGETALL", stats_key)
end

return cjson.encode(backup_data)
EOF

  kubectl cp "$TEMP_SCRIPT" "$NAMESPACE/$POD_NAME:/tmp/cache_backup.lua"

  if [ -n "$REDIS_PASSWORD" ]; then
    CACHE_DATA=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
      redis-cli -a "$REDIS_PASSWORD" --eval /tmp/cache_backup.lua 2>/dev/null || echo "{}")
  else
    CACHE_DATA=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
      redis-cli --eval /tmp/cache_backup.lua 2>/dev/null || echo "{}")
  fi

  echo "      \"data\": $CACHE_DATA" >> "$BACKUP_FILE"
  echo "    }" >> "$BACKUP_FILE"

  rm -f "$TEMP_SCRIPT"
}

# Execute backups based on selection
if [ "$BACKUP_AUTH" = true ] && [ "$BACKUP_CACHE" = true ]; then
  backup_auth
  echo "    ," >> "$BACKUP_FILE"
  backup_cache
elif [ "$BACKUP_AUTH" = true ]; then
  backup_auth
elif [ "$BACKUP_CACHE" = true ]; then
  backup_cache
fi

echo "  }" >> "$BACKUP_FILE"
echo "}" >> "$BACKUP_FILE"

if [ -s "$BACKUP_FILE" ]; then
  echo "✅ Backup completed successfully: $BACKUP_FILE"
  echo "📊 Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"

  # Show backup summary
  echo ""
  echo "📋 Backup Summary:"
  python3 -c "
import json
import sys

try:
    with open('$BACKUP_FILE', 'r') as f:
        data = json.load(f)

    print(f'  Backup timestamp: {data.get(\"timestamp\", \"unknown\")}')

    databases = data.get('databases', {})

    if 'auth' in databases:
        auth_data = databases['auth'].get('data', {})
        clients = auth_data.get('clients', {})
        access_tokens = auth_data.get('access_tokens', {})
        refresh_tokens = auth_data.get('refresh_tokens', {})
        auth_sessions = auth_data.get('auth_sessions', {})
        blacklisted = auth_data.get('blacklisted_tokens', {})
        print(f'  Auth database (DB 0):')
        print(f'    - OAuth2 clients: {len(clients)}')
        print(f'    - Access tokens: {len(access_tokens)}')
        print(f'    - Refresh tokens: {len(refresh_tokens)}')
        print(f'    - Auth sessions: {len(auth_sessions)}')
        print(f'    - Blacklisted tokens: {len(blacklisted)}')

    if 'cache' in databases:
        cache_data = databases['cache'].get('data', {})
        cache_entries = cache_data.get('cache_entries', {})
        total_cache_entries = sum(len(entries) for entries in cache_entries.values())
        print(f'  Cache database (DB 1):')
        print(f'    - Total cache entries: {total_cache_entries}')
        for cache_type, entries in cache_entries.items():
            print(f'    - {cache_type}: {len(entries)} entries')

except Exception as e:
    print(f'Error reading backup: {e}')
    print(f'Raw backup file size: $(du -h \""$BACKUP_FILE"\" | cut -f1)')
  "
else
  echo "❌ Backup failed or is empty"
  exit 1
fi

print_separator "="
echo "✅ Database backup completed."
print_separator "="
