#!/bin/bash
# Restore Redis service databases from backup files
# Usage: ./db-restore.sh <backup-file> [--service <service>] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

show_usage() {
  echo "Usage: $0 <backup-file> [options]"
  echo ""
  echo "Options:"
  echo "  --service <name>  Restore only specific service from backup"
  echo "  --dry-run         Preview what would be restored (no changes)"
  echo "  --flush           Clear database before restoring (DANGEROUS)"
  echo "  --help            Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 backups/20240101_120000_full.json"
  echo "  $0 backups/20240101_120000_full.json --service auth"
  echo "  $0 backups/20240101_120000_auth.json --dry-run"
  echo ""
  list_services
}

# Restore a single key
restore_key() {
  local db="$1"
  local key="$2"
  local key_type="$3"
  local ttl="$4"
  local value="$5"
  local dry_run="$6"

  if [[ "$dry_run" == true ]]; then
    echo "  Would restore: $key ($key_type, TTL: $ttl)"
    return 0
  fi

  case "$key_type" in
    string)
      local str_value
      str_value=$(echo "$value" | jq -r '.')
      redis_exec_raw "$db" SET "$key" "$str_value" > /dev/null
      ;;
    hash)
      # Delete existing key first
      redis_exec_raw "$db" DEL "$key" > /dev/null
      # Set hash fields
      echo "$value" | jq -r 'to_entries | .[] | "\(.key)\n\(.value)"' | while IFS= read -r field && IFS= read -r val; do
        [[ -z "$field" ]] && continue
        redis_exec_raw "$db" HSET "$key" "$field" "$val" > /dev/null
      done
      ;;
    list)
      redis_exec_raw "$db" DEL "$key" > /dev/null
      echo "$value" | jq -r '.[]' | while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        redis_exec_raw "$db" RPUSH "$key" "$item" > /dev/null
      done
      ;;
    set)
      redis_exec_raw "$db" DEL "$key" > /dev/null
      echo "$value" | jq -r '.[]' | while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        redis_exec_raw "$db" SADD "$key" "$item" > /dev/null
      done
      ;;
    zset)
      redis_exec_raw "$db" DEL "$key" > /dev/null
      echo "$value" | jq -r '.[] | "\(.score)\n\(.member)"' | while IFS= read -r score && IFS= read -r member; do
        [[ -z "$member" ]] && continue
        redis_exec_raw "$db" ZADD "$key" "$score" "$member" > /dev/null
      done
      ;;
    *)
      print_warning "Unknown type '$key_type' for key '$key', skipping"
      return 1
      ;;
  esac

  # Set TTL if specified
  if [[ "$ttl" -gt 0 ]]; then
    redis_exec_raw "$db" EXPIRE "$key" "$ttl" > /dev/null
  fi

  return 0
}

# Restore a single service
restore_service() {
  local service="$1"
  local backup_file="$2"
  local dry_run="$3"

  local db="${SERVICE_DB_MAP[$service]}"

  if [[ "$dry_run" == true ]]; then
    print_info "[DRY-RUN] Would restore $service (DB $db)..."
  else
    print_info "Restoring $service (DB $db)..."
  fi

  # Check if service exists in backup
  if ! jq -e ".services.\"$service\"" "$backup_file" > /dev/null 2>&1; then
    print_warning "Service '$service' not found in backup file"
    return 1
  fi

  local key_count
  key_count=$(jq -r ".services.\"$service\".key_count // 0" "$backup_file")
  echo "  Keys to restore: $key_count"

  if [[ "$key_count" == "0" ]]; then
    echo "  (no keys to restore)"
    return 0
  fi

  local restored=0
  local failed=0

  # Iterate over keys
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue

    local key_type
    local ttl
    local value

    key_type=$(jq -r ".services.\"$service\".keys.\"$key\".type // \"unknown\"" "$backup_file")
    ttl=$(jq -r ".services.\"$service\".keys.\"$key\".ttl // -1" "$backup_file")
    value=$(jq -c ".services.\"$service\".keys.\"$key\".value" "$backup_file")

    if restore_key "$db" "$key" "$key_type" "$ttl" "$value" "$dry_run"; then
      ((restored++)) || true
    else
      ((failed++)) || true
    fi

  done < <(jq -r ".services.\"$service\".keys | keys[]" "$backup_file" 2>/dev/null)

  echo "  Restored: $restored, Failed: $failed"
}

# Main
check_kubectl

BACKUP_FILE=""
SERVICE=""
DRY_RUN=false
FLUSH=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service|-s)
      SERVICE="$2"
      shift 2
      ;;
    --dry-run|-n)
      DRY_RUN=true
      shift
      ;;
    --flush)
      FLUSH=true
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
      BACKUP_FILE="$1"
      shift
      ;;
  esac
done

# Validate arguments
if [[ -z "$BACKUP_FILE" ]]; then
  print_error "Backup file required"
  show_usage
  exit 1
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
  print_error "Backup file not found: $BACKUP_FILE"
  exit 1
fi

# Validate JSON
if ! jq . "$BACKUP_FILE" > /dev/null 2>&1; then
  print_error "Invalid JSON in backup file"
  exit 1
fi

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

# Test connection
if ! redis_exec_raw 0 PING &>/dev/null; then
  print_error "Could not connect to Redis"
  exit 1
fi

# Get backup metadata
BACKUP_TIMESTAMP=$(jq -r '.timestamp // "unknown"' "$BACKUP_FILE")
BACKUP_NAMESPACE=$(jq -r '.namespace // "unknown"' "$BACKUP_FILE")

print_header "Redis Database Restore"
echo "Backup file: $BACKUP_FILE"
echo "Backup timestamp: $BACKUP_TIMESTAMP"
echo "Backup namespace: $BACKUP_NAMESPACE"
echo "Target namespace: $NAMESPACE"
echo "Mode: $(if [[ "$DRY_RUN" == true ]]; then echo "DRY-RUN"; else echo "LIVE"; fi)"

if [[ "$BACKUP_NAMESPACE" != "$NAMESPACE" ]]; then
  print_warning "Backup was created for different namespace: $BACKUP_NAMESPACE"
fi

# Get services to restore
SERVICES_TO_RESTORE=()
if [[ -n "$SERVICE" ]]; then
  SERVICES_TO_RESTORE=("$SERVICE")
else
  mapfile -t SERVICES_TO_RESTORE < <(jq -r '.services | keys[]' "$BACKUP_FILE" 2>/dev/null)
fi

echo "Services to restore: ${SERVICES_TO_RESTORE[*]}"

# Confirmation for live restore
if [[ "$DRY_RUN" == false ]]; then
  echo ""
  print_warning "This will overwrite existing data in the database!"
  read -r -p "Continue? [y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

# Flush databases if requested
if [[ "$FLUSH" == true ]] && [[ "$DRY_RUN" == false ]]; then
  print_warning "Flushing databases before restore..."
  for svc in "${SERVICES_TO_RESTORE[@]}"; do
    db="${SERVICE_DB_MAP[$svc]}"
    redis_exec_raw "$db" FLUSHDB > /dev/null
    echo "  Flushed DB $db ($svc)"
  done
fi

echo ""
print_info "Starting restore..."

# Restore each service
for svc in "${SERVICES_TO_RESTORE[@]}"; do
  restore_service "$svc" "$BACKUP_FILE" "$DRY_RUN"
done

echo ""
if [[ "$DRY_RUN" == true ]]; then
  print_success "Dry-run completed. No changes were made."
else
  print_success "Restore completed."
fi
