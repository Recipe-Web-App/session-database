#!/bin/bash
# Backup Redis service databases to JSON files
# Usage: ./db-backup.sh [service1] [service2] ...

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

show_usage() {
  echo "Usage: $0 [service1] [service2] ..."
  echo ""
  echo "Options:"
  echo "  <service>  Backup specific service(s) (default: all services)"
  echo "  --help     Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0                       # Backup all services"
  echo "  $0 auth                  # Backup only auth service"
  echo "  $0 auth scraper-cache    # Backup auth and scraper-cache"
  echo ""
  list_services
}

# Backup a single service to JSON
backup_service() {
  local service="$1"
  local db="${SERVICE_DB_MAP[$service]}"
  local desc="${SERVICE_NAMES[$db]}"

  print_info "Backing up $service (DB $db)..."

  local keys
  keys=$(get_db_keys "$db" 2>/dev/null || echo "")

  local key_count=0
  local backup_data="{"
  backup_data+="\"service\":\"$service\","
  backup_data+="\"database\":$db,"
  backup_data+="\"description\":\"$desc\","
  backup_data+="\"timestamp\":\"$TIMESTAMP\","
  backup_data+="\"keys\":{"

  local first=true

  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    ((key_count++)) || true

    local key_type
    local ttl
    local value=""

    key_type=$(get_key_type "$db" "$key" 2>/dev/null || echo "unknown")
    ttl=$(get_key_ttl "$db" "$key" 2>/dev/null || echo "-1")

    # Get value based on type
    case "$key_type" in
      string)
        value=$(redis_exec_raw "$db" GET "$key" 2>/dev/null | jq -Rs . || echo "null")
        ;;
      hash)
        value=$(redis_exec_raw "$db" HGETALL "$key" 2>/dev/null | jq -Rs 'split("\n") | if length > 0 then [range(0; length; 2) as $i | {(.[($i)]): .[($i+1)]}] | add // {} else {} end' || echo "{}")
        ;;
      list)
        value=$(redis_exec_raw "$db" LRANGE "$key" 0 -1 2>/dev/null | jq -Rs 'split("\n") | map(select(. != ""))' || echo "[]")
        ;;
      set)
        value=$(redis_exec_raw "$db" SMEMBERS "$key" 2>/dev/null | jq -Rs 'split("\n") | map(select(. != ""))' || echo "[]")
        ;;
      zset)
        value=$(redis_exec_raw "$db" ZRANGE "$key" 0 -1 WITHSCORES 2>/dev/null | jq -Rs 'split("\n") | map(select(. != "")) | [range(0; length; 2) as $i | {member: .[($i)], score: .[($i+1)]}]' || echo "[]")
        ;;
      *)
        value="null"
        ;;
    esac

    # Escape key for JSON
    local escaped_key
    escaped_key=$(echo "$key" | jq -Rs .)

    if [[ "$first" == true ]]; then
      first=false
    else
      backup_data+=","
    fi

    backup_data+="$escaped_key:{\"type\":\"$key_type\",\"ttl\":$ttl,\"value\":$value}"

  done <<< "$keys"

  backup_data+="},"
  backup_data+="\"key_count\":$key_count"
  backup_data+="}"

  echo "$backup_data"
}

# Main
check_kubectl

SERVICES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
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
      SERVICES+=("$1")
      shift
      ;;
  esac
done

# Default to all services
if [[ ${#SERVICES[@]} -eq 0 ]]; then
  mapfile -t SERVICES < <(get_all_services | tr ' ' '\n' | sort)
fi

# Validate services
for svc in "${SERVICES[@]}"; do
  validate_service "$svc" || exit 1
done

# Check Redis connectivity
MASTER_POD=$(get_master_pod)
if [[ -z "$MASTER_POD" ]]; then
  print_error "Could not find Redis master pod in namespace $NAMESPACE"
  exit 1
fi

# Test connection
if ! redis_exec_raw 0 PING &>/dev/null; then
  print_error "Could not connect to Redis"
  exit 1
fi

print_header "Redis Database Backup"
echo "Namespace: $NAMESPACE"
echo "Pod: $MASTER_POD"
echo "Timestamp: $TIMESTAMP"
echo "Services: ${SERVICES[*]}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Determine backup filename
if [[ ${#SERVICES[@]} -eq 7 ]]; then
  BACKUP_FILE="$BACKUP_DIR/${TIMESTAMP}_full.json"
elif [[ ${#SERVICES[@]} -eq 1 ]]; then
  BACKUP_FILE="$BACKUP_DIR/${TIMESTAMP}_${SERVICES[0]}.json"
else
  BACKUP_FILE="$BACKUP_DIR/${TIMESTAMP}_partial.json"
fi

echo ""
print_info "Starting backup..."

# Build complete backup JSON
{
  echo "{"
  echo "\"backup_type\":\"redis\","
  echo "\"timestamp\":\"$TIMESTAMP\","
  echo "\"namespace\":\"$NAMESPACE\","
  echo "\"services\":{"

  first=true
  for svc in "${SERVICES[@]}"; do
    if [[ "$first" == true ]]; then
      first=false
    else
      echo ","
    fi
    echo "\"$svc\":"
    backup_service "$svc"
  done

  echo "}"
  echo "}"
} > "$BACKUP_FILE"

# Validate JSON
if ! jq . "$BACKUP_FILE" > /dev/null 2>&1; then
  print_warning "Backup file may have JSON formatting issues"
fi

# Show summary
echo ""
print_header "Backup Summary"
echo "File: $BACKUP_FILE"
echo "Size: $(du -h "$BACKUP_FILE" | cut -f1)"
echo ""

for svc in "${SERVICES[@]}"; do
  db="${SERVICE_DB_MAP[$svc]}"
  count=$(jq -r ".services.\"$svc\".key_count // 0" "$BACKUP_FILE" 2>/dev/null || echo "?")
  printf "  %-20s %s keys\n" "$svc:" "$count"
done

echo ""
print_success "Backup completed: $BACKUP_FILE"
