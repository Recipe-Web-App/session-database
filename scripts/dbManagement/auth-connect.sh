#!/bin/bash
# scripts/dbManagement/auth-connect.sh

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
DATABASE=${1:-0}  # Default to auth database (DB 0), can be overridden

# Validate database number
if ! [[ "$DATABASE" =~ ^[0-9]+$ ]] || [ "$DATABASE" -lt 0 ] || [ "$DATABASE" -gt 15 ]; then
  echo "❌ Invalid database number: $DATABASE (must be 0-15)"
  echo "   Usage: $0 [database_number]"
  echo "   Examples:"
  echo "     $0     # Connect to auth database (DB 0)"
  echo "     $0 0   # Connect to auth database (DB 0)"
  echo "     $0 1   # Connect to cache database (DB 1)"
  exit 1
fi

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
echo "🔐 Starting redis-cli inside pod for database $DATABASE..."
if [ "$DATABASE" = "0" ]; then
  echo "   Connecting to auth database (DB 0)"
  echo "   Available auth patterns:"
  echo "     auth:client:*        - OAuth2 client registrations"
  echo "     auth:code:*          - Authorization codes"
  echo "     auth:access_token:*  - Access token metadata"
  echo "     auth:refresh_token:* - Refresh token metadata"
  echo "     auth:session:*       - User authentication sessions"
  echo "     auth:blacklist:*     - Revoked token tracking"
  echo "     auth:rate_limit:*    - Request rate limiting"
elif [ "$DATABASE" = "1" ]; then
  echo "   Connecting to cache database (DB 1)"
else
  echo "   Connecting to database $DATABASE"
fi
print_separator "-"

if [ -n "$REDIS_PASSWORD" ]; then
  kubectl exec -it -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -a "$REDIS_PASSWORD" -n "$DATABASE"
else
  kubectl exec -it -n "$NAMESPACE" "$POD_NAME" -- \
    redis-cli -n "$DATABASE"
fi

print_separator "="
echo "✅ redis-cli session ended."
print_separator "="
