#!/bin/bash
# Monitor Redis service databases in real-time
# Usage: ./service-monitor.sh [service] [--watch]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

COLUMNS=$(tput cols 2>/dev/null || echo 80)

show_usage() {
  echo "Usage: $0 [service] [--watch]"
  echo ""
  echo "Options:"
  echo "  <service>    Monitor specific service (default: all services)"
  echo "  --watch, -w  Continuous monitoring (refresh every 5s)"
  echo "  --help, -h   Show this help message"
  echo ""
  list_services
}

# Get Redis server info
get_server_info() {
  local pod
  local password
  pod=$(get_master_pod)
  password=$(get_redis_password)

  kubectl exec -n "$NAMESPACE" "$pod" -- \
    redis-cli -a "$password" --no-auth-warning INFO server 2>/dev/null
}

# Get Redis memory info
get_memory_info() {
  local pod
  local password
  pod=$(get_master_pod)
  password=$(get_redis_password)

  kubectl exec -n "$NAMESPACE" "$pod" -- \
    redis-cli -a "$password" --no-auth-warning INFO memory 2>/dev/null
}

# Get Redis clients info
get_clients_info() {
  local pod
  local password
  pod=$(get_master_pod)
  password=$(get_redis_password)

  kubectl exec -n "$NAMESPACE" "$pod" -- \
    redis-cli -a "$password" --no-auth-warning INFO clients 2>/dev/null
}

# Show quick health for all services
show_all_health() {
  print_header "Redis Health Overview"
  echo "Namespace: $NAMESPACE"
  echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""

  # Server info
  local uptime
  local version
  uptime=$(get_server_info | grep -E "^uptime_in_days:" | cut -d: -f2 | tr -d '[:space:]')
  version=$(get_server_info | grep -E "^redis_version:" | cut -d: -f2 | tr -d '[:space:]')
  echo "Redis Version: ${version:-unknown}"
  echo "Uptime: ${uptime:-?} days"

  # Memory info
  local mem_used
  local mem_peak
  mem_used=$(get_memory_info | grep -E "^used_memory_human:" | cut -d: -f2 | tr -d '[:space:]')
  mem_peak=$(get_memory_info | grep -E "^used_memory_peak_human:" | cut -d: -f2 | tr -d '[:space:]')
  echo "Memory: ${mem_used:-?} (peak: ${mem_peak:-?})"

  # Clients info
  local clients
  clients=$(get_clients_info | grep -E "^connected_clients:" | cut -d: -f2 | tr -d '[:space:]')
  echo "Connected clients: ${clients:-?}"

  echo ""
  printf "%-20s %-6s %10s %12s\n" "SERVICE" "DB" "KEYS" "STATUS"
  printf '%*s\n' "$COLUMNS" '' | tr ' ' '-'

  for svc in $(get_all_services | tr ' ' '\n' | sort); do
    local db="${SERVICE_DB_MAP[$svc]}"
    local key_count
    key_count=$(get_db_key_count "$db" 2>/dev/null || echo "?")

    local status="OK"
    if [[ "$key_count" == "?" ]]; then
      status="ERROR"
    elif [[ "$key_count" == "0" ]]; then
      status="EMPTY"
    fi

    printf "%-20s %-6s %10s %12s\n" "$svc" "$db" "$key_count" "$status"
  done
}

# Show detailed monitoring for a service
show_service_monitor() {
  local service="$1"
  local db="${SERVICE_DB_MAP[$service]}"
  local desc="${SERVICE_NAMES[$db]}"

  print_header "Monitoring: $service (DB $db)"
  echo "Purpose: $desc"
  echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""

  # Key count
  local key_count
  key_count=$(get_db_key_count "$db" 2>/dev/null || echo "0")
  echo "Total keys: $key_count"

  if [[ "$key_count" == "0" ]]; then
    echo ""
    echo "Database is empty - no additional metrics available."
    return
  fi

  # Analyze keys
  local keys
  keys=$(get_db_keys "$db")

  local total=0
  local ttl_none=0
  local ttl_expiring=0
  local ttl_healthy=0
  local total_mem=0

  declare -A type_counts
  declare -A prefix_counts

  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    ((total++)) || true

    # Type
    local key_type
    key_type=$(get_key_type "$db" "$key" 2>/dev/null || echo "unknown")
    ((type_counts[$key_type]++)) || type_counts[$key_type]=1

    # TTL
    local ttl
    ttl=$(get_key_ttl "$db" "$key" 2>/dev/null || echo "-1")
    if [[ "$ttl" == "-1" ]]; then
      ((ttl_none++)) || true
    elif [[ "$ttl" -lt 300 ]] && [[ "$ttl" -ge 0 ]]; then
      ((ttl_expiring++)) || true
    elif [[ "$ttl" -ge 300 ]]; then
      ((ttl_healthy++)) || true
    fi

    # Memory
    local mem
    mem=$(get_key_memory "$db" "$key" 2>/dev/null || echo "0")
    if [[ "$mem" =~ ^[0-9]+$ ]]; then
      ((total_mem += mem)) || true
    fi

    # Key prefix (first segment before :)
    local prefix
    prefix=$(echo "$key" | cut -d: -f1)
    ((prefix_counts[$prefix]++)) || prefix_counts[$prefix]=1

  done <<< "$keys"

  echo ""
  echo "Key Types:"
  for t in "${!type_counts[@]}"; do
    printf "  %-15s %d\n" "$t" "${type_counts[$t]}"
  done

  echo ""
  echo "Key Prefixes:"
  for p in "${!prefix_counts[@]}"; do
    printf "  %-20s %d\n" "$p:" "${prefix_counts[$p]}"
  done

  echo ""
  echo "TTL Distribution:"
  echo "  No expiry:      $ttl_none"
  echo "  Expiring (<5m): $ttl_expiring"
  echo "  Healthy (>5m):  $ttl_healthy"

  echo ""
  echo "Memory:"
  if [[ $total_mem -gt 1048576 ]]; then
    echo "  Total: $((total_mem / 1048576)) MB"
  elif [[ $total_mem -gt 1024 ]]; then
    echo "  Total: $((total_mem / 1024)) KB"
  else
    echo "  Total: $total_mem bytes"
  fi
}

# Main
check_kubectl

WATCH=false
SERVICE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --watch|-w)
      WATCH=true
      shift
      ;;
    --help|-h)
      show_usage
      exit 0
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

if [[ -n "$SERVICE" ]]; then
  validate_service "$SERVICE" || exit 1
fi

MASTER_POD=$(get_master_pod)
if [[ -z "$MASTER_POD" ]]; then
  print_error "Could not find Redis master pod in namespace $NAMESPACE"
  exit 1
fi

if [[ "$WATCH" == true ]]; then
  while true; do
    clear
    if [[ -n "$SERVICE" ]]; then
      show_service_monitor "$SERVICE"
    else
      show_all_health
    fi
    echo ""
    echo "Refreshing in 5 seconds... (Ctrl+C to exit)"
    sleep 5
  done
else
  if [[ -n "$SERVICE" ]]; then
    show_service_monitor "$SERVICE"
  else
    show_all_health
  fi
  echo ""
  print_success "Done"
fi
