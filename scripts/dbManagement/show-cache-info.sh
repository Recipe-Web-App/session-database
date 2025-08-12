#!/bin/bash
# scripts/dbManagement/show-cache-info.sh
# Display comprehensive cache information from service cache database (DB 1)

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
CACHE_DB="1"

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
echo "🗄️  Service Cache Database (DB 1) - Recipe Scraper Service"
print_separator "-"

# Function to execute Redis commands
redis_cmd() {
  if [ -n "$REDIS_PASSWORD" ]; then
    kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
      redis-cli -a "$REDIS_PASSWORD" -n "$CACHE_DB" --raw "$@" 2>/dev/null
  else
    kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
      redis-cli -n "$CACHE_DB" --raw "$@" 2>/dev/null
  fi
}

# Database overview and real-time statistics
echo "💾 Database Overview:"
db_size=$(redis_cmd DBSIZE 2>/dev/null || echo "0")
echo "   Total cache keys: $db_size"

# Calculate real-time cache statistics
echo ""
echo "📊 Cache Statistics (Real-time):"
cache_data_count=$(redis_cmd EVAL "return #redis.call('KEYS', 'cache:resource:*')" 0 2>/dev/null || echo "0")
echo "   active_cache_entries     : $cache_data_count"
echo "   total_cache_entries      : $cache_data_count"

# Show stored statistics from cleanup job (if available)
cache_stats=$(redis_cmd HGETALL cache_stats 2>/dev/null || echo "")
if [ -n "$cache_stats" ]; then
  echo ""
  echo "📈 Cleanup Job Statistics:"
  echo "$cache_stats" | while IFS= read -r key && IFS= read -r value; do
    [ -n "$key" ] && printf "   %-25s: %s\n" "$key" "$value"
  done
fi

# Get cache configuration
echo ""
echo "⚙️  Cache Configuration:"
cache_config=$(redis_cmd HGETALL cache_config 2>/dev/null || echo "")
if [ -n "$cache_config" ]; then
  echo "$cache_config" | while IFS= read -r key && IFS= read -r value; do
    [ -n "$key" ] && printf "   %-25s: %s\n" "$key" "$value"
  done
else
  echo "   Default TTL: 24 hours (86400 seconds)"
  echo "   Database: 1"
fi

# Show all current cache entries
echo ""
echo "🗂️  Current Cache Entries:"
all_cache_keys=$(redis_cmd KEYS "cache:*" 2>/dev/null || echo "")
if [ -n "$all_cache_keys" ] && [ "$all_cache_keys" != "(empty list or set)" ]; then
  echo "$all_cache_keys" | while IFS= read -r key; do
    if [ -n "$key" ] && [ "$key" != "(empty list or set)" ]; then
      ttl=$(redis_cmd TTL "$key" 2>/dev/null || echo "-1")
      size=$(redis_cmd MEMORY USAGE "$key" 2>/dev/null || echo "unknown")

      # Handle TTL parsing more safely
      if [[ "$ttl" =~ ^-?[0-9]+$ ]] && [ "$ttl" -gt 0 ]; then
        ttl_hours=$((ttl / 3600))
        ttl_mins=$(((ttl % 3600) / 60))
        echo "   📦 $key"
        echo "       TTL: ${ttl_hours}h ${ttl_mins}m (${ttl}s remaining)"
        if [ "$size" != "unknown" ] && [[ "$size" =~ ^[0-9]+$ ]]; then
          echo "       Size: ${size} bytes"
        fi
      elif [[ "$ttl" =~ ^-?[0-9]+$ ]] && [ "$ttl" -eq -1 ]; then
        echo "   📦 $key (no expiration)"
        if [ "$size" != "unknown" ] && [[ "$size" =~ ^[0-9]+$ ]]; then
          echo "       Size: ${size} bytes"
        fi
      else
        echo "   📦 $key (TTL: $ttl)"
        if [ "$size" != "unknown" ] && [[ "$size" =~ ^[0-9]+$ ]]; then
          echo "       Size: ${size} bytes"
        fi
      fi
    fi
  done
else
  echo "   (No cache entries found - recipe scraper may not have run yet)"
fi

# Get cleanup metrics
echo ""
echo "🧹 Cleanup Information:"
cleanup_metrics=$(redis_cmd HGETALL cache_cleanup_metrics 2>/dev/null || echo "")
if [ -n "$cleanup_metrics" ]; then
  echo "$cleanup_metrics" | while IFS= read -r key && IFS= read -r value; do
    [ -n "$key" ] && printf "   %-30s: %s\n" "$key" "$value"
  done
else
  echo "   (Cleanup metrics not available)"
fi

# Cache key patterns
echo ""
echo "🗝️  Supported Cache Patterns:"
key_patterns=$(redis_cmd HGETALL cache_key_patterns 2>/dev/null || echo "")
if [ -n "$key_patterns" ]; then
  echo "$key_patterns" | while IFS= read -r key && IFS= read -r value; do
    [ -n "$key" ] && printf "   %-15s: %s\n" "$key" "$value"
  done
else
  echo "   resource: cache:resource:* (for recipe scraper service)"
fi

print_separator "="
echo "✅ Cache information display completed."
print_separator "="
