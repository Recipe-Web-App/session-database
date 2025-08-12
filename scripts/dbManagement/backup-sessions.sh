#!/bin/bash
# scripts/dbManagement/backup-sessions.sh

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
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DATABASE=${1:-"all"}  # Default to backing up all databases

# Validate database selection
case "$DATABASE" in
  "all"|"sessions"|"cache"|"0"|"1")
    # Valid options
    ;;
  *)
    echo "❌ Invalid database option: $DATABASE"
    echo "   Usage: $0 [all|sessions|cache|0|1]"
    echo "   Examples:"
    echo "     $0           # Backup all databases (default)"
    echo "     $0 all       # Backup all databases"
    echo "     $0 sessions  # Backup only session database (DB 0)"
    echo "     $0 cache     # Backup only cache database (DB 1)"
    echo "     $0 0         # Backup only session database (DB 0)"
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
BACKUP_SESSIONS=false
BACKUP_CACHE=false

case "$DATABASE" in
  "all")
    BACKUP_SESSIONS=true
    BACKUP_CACHE=true
    BACKUP_FILE="$BACKUP_DIR/full_backup_$TIMESTAMP.json"
    ;;
  "sessions"|"0")
    BACKUP_SESSIONS=true
    BACKUP_FILE="$BACKUP_DIR/sessions_backup_$TIMESTAMP.json"
    ;;
  "cache"|"1")
    BACKUP_CACHE=true
    BACKUP_FILE="$BACKUP_DIR/cache_backup_$TIMESTAMP.json"
    ;;
esac

print_separator "="
echo "💾 Starting backup for: $DATABASE"
[ "$BACKUP_SESSIONS" = true ] && echo "   - Session database (DB 0)"
[ "$BACKUP_CACHE" = true ] && echo "   - Cache database (DB 1)"
print_separator "-"

# Create backup data structure
echo "{" > "$BACKUP_FILE"
echo "  \"timestamp\": \"$TIMESTAMP\"," >> "$BACKUP_FILE"
echo "  \"databases\": {" >> "$BACKUP_FILE"

# Function to backup session database (DB 0)
backup_sessions() {
  echo "    \"sessions\": {" >> "$BACKUP_FILE"
  echo "      \"database\": 0," >> "$BACKUP_FILE"

  # Create Lua script for session backup
  TEMP_SCRIPT=$(mktemp)
  cat > "$TEMP_SCRIPT" << 'EOF'
-- Switch to session database
redis.call("SELECT", 0)

local session_prefix = "session:"
local user_sessions_prefix = "user_sessions:"
local session_cleanup_key = "session_cleanup"
local session_stats_key = "session_stats"

local backup_data = {}

-- Get all session keys
local session_keys = redis.call("KEYS", session_prefix .. "*")
backup_data.sessions = {}
for i, key in ipairs(session_keys) do
    local session_data = redis.call("HGETALL", key)
    if #session_data > 0 then
        local session_id = string.sub(key, #session_prefix + 1)
        backup_data.sessions[session_id] = session_data
    end
end

-- Get user sessions
local user_session_keys = redis.call("KEYS", user_sessions_prefix .. "*")
backup_data.user_sessions = {}
for i, key in ipairs(user_session_keys) do
    local user_id = string.sub(key, #user_sessions_prefix + 1)
    local session_ids = redis.call("SMEMBERS", key)
    backup_data.user_sessions[user_id] = session_ids
end

-- Get cleanup data
backup_data.cleanup_data = redis.call("ZRANGE", session_cleanup_key, 0, -1, "WITHSCORES")

-- Get statistics
backup_data.statistics = redis.call("HGETALL", session_stats_key)

return cjson.encode(backup_data)
EOF

  kubectl cp "$TEMP_SCRIPT" "$NAMESPACE/$POD_NAME:/tmp/session_backup.lua"

  if [ -n "$REDIS_PASSWORD" ]; then
    SESSION_DATA=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
      redis-cli -a "$REDIS_PASSWORD" --eval /tmp/session_backup.lua 2>/dev/null || echo "{}")
  else
    SESSION_DATA=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
      redis-cli --eval /tmp/session_backup.lua 2>/dev/null || echo "{}")
  fi

  echo "      \"data\": $SESSION_DATA" >> "$BACKUP_FILE"
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
if [ "$BACKUP_SESSIONS" = true ] && [ "$BACKUP_CACHE" = true ]; then
  backup_sessions
  echo "    ," >> "$BACKUP_FILE"
  backup_cache
elif [ "$BACKUP_SESSIONS" = true ]; then
  backup_sessions
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

    if 'sessions' in databases:
        session_data = databases['sessions'].get('data', {})
        sessions = session_data.get('sessions', {})
        user_sessions = session_data.get('user_sessions', {})
        print(f'  Session database (DB 0):')
        print(f'    - Sessions: {len(sessions)}')
        print(f'    - Users: {len(user_sessions)}')

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
