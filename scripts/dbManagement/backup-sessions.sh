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
echo "📦 Creating backup directory..."
print_separator "-"

mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/sessions_backup_$TIMESTAMP.json"

print_separator "="
echo "💾 Starting session backup..."
print_separator "-"

# Create backup script
BACKUP_SCRIPT=$(cat << 'EOF'
-- Backup all session data
local session_prefix = "session:"
local user_sessions_prefix = "user_sessions:"
local session_cleanup_key = "session_cleanup"
local session_stats_key = "session_stats"

local backup_data = {}

-- Get all session keys
local session_keys = redis.call("KEYS", session_prefix .. "*")
for i, key in ipairs(session_keys) do
    local session_data = redis.call("GET", key)
    if session_data then
        local session_id = string.sub(key, #session_prefix + 1)
        backup_data[session_id] = session_data
    end
end

-- Get user sessions
local user_session_keys = redis.call("KEYS", user_sessions_prefix .. "*")
for i, key in ipairs(user_session_keys) do
    local user_id = string.sub(key, #user_sessions_prefix + 1)
    local session_ids = redis.call("SMEMBERS", key)
    backup_data["user_sessions_" .. user_id] = session_ids
end

-- Get cleanup data
local cleanup_data = redis.call("ZRANGE", session_cleanup_key, 0, -1, "WITHSCORES")
backup_data["cleanup_data"] = cleanup_data

-- Get statistics
local stats = redis.call("HGETALL", session_stats_key)
backup_data["statistics"] = stats

return cjson.encode(backup_data)
EOF
)

if [ -n "$REDIS_PASSWORD" ]; then
  kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -a "$REDIS_PASSWORD" --eval <(echo "$BACKUP_SCRIPT") > "$BACKUP_FILE"
else
  kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli --eval <(echo "$BACKUP_SCRIPT") > "$BACKUP_FILE"
fi

if [ -s "$BACKUP_FILE" ]; then
  echo "✅ Backup completed successfully: $BACKUP_FILE"
  echo "📊 Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"
else
  echo "❌ Backup failed or is empty"
  exit 1
fi

print_separator "="
echo "✅ Session backup completed."
print_separator "="
