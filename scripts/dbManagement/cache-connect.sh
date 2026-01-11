#!/bin/bash
# scripts/dbManagement/cache-connect.sh
# Connect to Redis cache database (DB 1) with cache-specific utilities

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
echo "🗄️  Connecting to Redis Cache Database (DB 1)..."
echo "   Cache database contains service cache data"
echo "   Available cache types: user_profile, api_response, computation, resource"
print_separator "-"

# Display cache statistics before connecting
if [ -n "$REDIS_PASSWORD" ]; then
  echo "📊 Cache Statistics:"
  kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -a "$REDIS_PASSWORD" -n "$CACHE_DB" --no-raw HGETALL cache_stats 2>/dev/null | \
    awk 'NR%2==1{key=$0} NR%2==0{printf "   %-25s: %s\n", key, $0}' || \
    echo "   (Cache statistics not yet available)"

  echo ""
  echo "🔧 Useful cache commands:"
  echo "   HGETALL cache_stats              # View cache statistics"
  echo "   HGETALL cache_config             # View cache configuration"
  echo "   KEYS cache:user_profile:*        # List user profile cache entries"
  echo "   KEYS cache:api_response:*        # List API response cache entries"
  echo "   KEYS cache:computation:*         # List computation cache entries"
  echo "   KEYS cache:resource:*            # List resource cache entries"
  echo "   HGETALL cache_cleanup_metrics    # View cleanup metrics"
  echo "   HGETALL cache_performance        # View performance metrics"
  echo ""

  print_separator "-"

  kubectl exec -it -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -a "$REDIS_PASSWORD" -n "$CACHE_DB"
else
  echo "📊 Cache Statistics:"
  kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -n "$CACHE_DB" --no-raw HGETALL cache_stats 2>/dev/null | \
    awk 'NR%2==1{key=$0} NR%2==0{printf "   %-25s: %s\n", key, $0}' || \
    echo "   (Cache statistics not yet available)"

  echo ""
  echo "🔧 Useful cache commands:"
  echo "   HGETALL cache_stats              # View cache statistics"
  echo "   HGETALL cache_config             # View cache configuration"
  echo "   KEYS cache:user_profile:*        # List user profile cache entries"
  echo "   KEYS cache:api_response:*        # List API response cache entries"
  echo "   KEYS cache:computation:*         # List computation cache entries"
  echo "   KEYS cache:resource:*            # List resource cache entries"
  echo "   HGETALL cache_cleanup_metrics    # View cleanup metrics"
  echo "   HGETALL cache_performance        # View performance metrics"
  echo ""

  print_separator "-"

  kubectl exec -it -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -n "$CACHE_DB"
fi

print_separator "="
echo "✅ Cache redis-cli session ended."
print_separator "="
