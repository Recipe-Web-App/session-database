#!/bin/bash
# View information for Redis service databases
# Usage: ./service-info.sh [service] [--detailed]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

# Terminal width for formatting
COLUMNS=$(tput cols 2>/dev/null || echo 80)

show_usage() {
  echo "Usage: $0 [service] [--detailed]"
  echo ""
  echo "Options:"
  echo "  <service>    Show info for specific service (default: all services)"
  echo "  --detailed   Show detailed key information"
  echo "  --help       Show this help message"
  echo ""
  list_services
}

# Show summary stats for a single service
show_service_summary() {
  local service="$1"
  local db="${SERVICE_DB_MAP[$service]}"
  local desc="${SERVICE_NAMES[$db]}"

  local key_count
  key_count=$(get_db_key_count "$db" 2>/dev/null || echo "0")

  printf "  %-20s DB %-2s  %6s keys  %s\n" "$service" "$db" "$key_count" "$desc"
}

# Show detailed info for a single service
show_service_detailed() {
  local service="$1"
  local db="${SERVICE_DB_MAP[$service]}"
  local desc="${SERVICE_NAMES[$db]}"

  print_header "$service (DB $db) - $desc"

  local key_count
  key_count=$(get_db_key_count "$db" 2>/dev/null || echo "0")
  echo "Total keys: $key_count"

  if [[ "$key_count" == "0" ]]; then
    echo "  (no keys found)"
    return
  fi

  echo ""
  echo "Keys:"

  local keys
  keys=$(get_db_keys "$db")

  local ttl_none=0
  local ttl_expiring=0
  local ttl_healthy=0

  while IFS= read -r key; do
    [[ -z "$key" ]] && continue

    local key_type
    local ttl
    local mem

    key_type=$(get_key_type "$db" "$key" 2>/dev/null || echo "unknown")
    ttl=$(get_key_ttl "$db" "$key" 2>/dev/null || echo "-1")
    mem=$(get_key_memory "$db" "$key" 2>/dev/null || echo "?")

    # Track TTL distribution
    if [[ "$ttl" == "-1" ]]; then
      ((ttl_none++)) || true
      ttl_display="no expiry"
    elif [[ "$ttl" == "-2" ]]; then
      ttl_display="expired"
    elif [[ "$ttl" -lt 300 ]]; then
      ((ttl_expiring++)) || true
      ttl_display="${ttl}s (expiring soon)"
    else
      ((ttl_healthy++)) || true
      local hours=$((ttl / 3600))
      local mins=$(((ttl % 3600) / 60))
      if [[ $hours -gt 0 ]]; then
        ttl_display="${hours}h ${mins}m"
      else
        ttl_display="${mins}m"
      fi
    fi

    printf "  %-50s %-10s %8s bytes  TTL: %s\n" "$key" "($key_type)" "$mem" "$ttl_display"
  done <<< "$keys"

  echo ""
  echo "TTL Summary:"
  echo "  No expiry:      $ttl_none"
  echo "  Expiring (<5m): $ttl_expiring"
  echo "  Healthy:        $ttl_healthy"
}

# Main
check_kubectl

DETAILED=false
SERVICE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --detailed|-d)
      DETAILED=true
      shift
      ;;
    --help|-h)
      show_usage
      exit 0
      ;;
    --all|-a)
      SERVICE=""
      shift
      ;;
    -*)
      print_error "Unknown option: $1"
      show_usage
      exit 1
      ;;
    *)
      SERVICE="$1"
      shift
      ;;
  esac
done

# Validate service if specified
if [[ -n "$SERVICE" ]]; then
  validate_service "$SERVICE" || exit 1
fi

# Check Redis connectivity
MASTER_POD=$(get_master_pod)
if [[ -z "$MASTER_POD" ]]; then
  print_error "Could not find Redis master pod in namespace $NAMESPACE"
  exit 1
fi

print_header "Redis Service Database Info"
echo "Namespace: $NAMESPACE"
echo "Pod: $MASTER_POD"

if [[ -n "$SERVICE" ]]; then
  # Single service
  if [[ "$DETAILED" == true ]]; then
    show_service_detailed "$SERVICE"
  else
    echo ""
    echo "Service:"
    show_service_summary "$SERVICE"
  fi
else
  # All services
  if [[ "$DETAILED" == true ]]; then
    for svc in $(get_all_services | tr ' ' '\n' | sort); do
      show_service_detailed "$svc"
    done
  else
    echo ""
    echo "Services:"
    for svc in $(get_all_services | tr ' ' '\n' | sort); do
      show_service_summary "$svc"
    done
  fi
fi

echo ""
print_success "Done"
