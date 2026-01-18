#!/bin/bash
# Connect to a specific service's Redis database
# Usage: ./service-connect.sh <service-name>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

check_kubectl

SERVICE="${1:-}"

if [[ -z "$SERVICE" ]] || [[ -z "${SERVICE_DB_MAP[$SERVICE]:-}" ]]; then
  echo "Usage: $0 <service-name>"
  echo ""
  list_services
  exit 1
fi

DATABASE="${SERVICE_DB_MAP[$SERVICE]}"
SERVICE_DESC="${SERVICE_NAMES[$DATABASE]}"

echo "=============================================="
echo "Connecting to Redis Database"
echo "=============================================="
echo "Service:   $SERVICE"
echo "Database:  DB $DATABASE"
echo "Purpose:   $SERVICE_DESC"
echo "Namespace: $NAMESPACE"
echo "=============================================="
echo ""

# Get the master pod
MASTER_POD=$(get_master_pod)
if [[ -z "$MASTER_POD" ]]; then
  print_error "Could not find Redis master pod in namespace $NAMESPACE"
  exit 1
fi

# Get the password
REDIS_PASSWORD=$(get_redis_password)
if [[ -z "$REDIS_PASSWORD" ]]; then
  print_error "Could not retrieve Redis password from secret"
  exit 1
fi

print_info "Connecting to pod: $MASTER_POD"
echo ""

# Connect interactively
kubectl exec -it -n "$NAMESPACE" "$MASTER_POD" -- \
  redis-cli -a "$REDIS_PASSWORD" --no-auth-warning -n "$DATABASE"
