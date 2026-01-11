#!/bin/bash
# Initialize all service databases with their Lua scripts
# Each service gets its own dedicated database for isolation

set -e

REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"
SCRIPT_DIR="/usr/local/etc/redis/scripts"

echo "=============================================="
echo "Redis Multi-Service Database Initialization"
echo "=============================================="
echo "Host: ${REDIS_HOST}:${REDIS_PORT}"
echo ""

# Wait for Redis to be ready
echo "Waiting for Redis to be ready..."
for i in {1..30}; do
  if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ${REDIS_PASSWORD:+-a "$REDIS_PASSWORD"} --no-auth-warning ping 2>/dev/null | grep -q PONG; then
    echo "Redis is ready!"
    break
  fi
  echo "  Attempt $i/30 - waiting..."
  sleep 2
done

# Service init scripts with their target databases
declare -A INIT_SCRIPTS=(
  ["001_init_auth_service.lua"]=0
  ["002_init_scraper_cache.lua"]=1
  ["003_init_scraper_queue.lua"]=2
  ["004_init_scraper_ratelimit.lua"]=3
  ["005_init_user_management.lua"]=4
  ["006_init_notification.lua"]=5
  ["007_init_mealplan.lua"]=6
)

# Service descriptions for logging
declare -A SERVICE_NAMES=(
  [0]="Auth Service (OAuth2)"
  [1]="Recipe Scraper Cache"
  [2]="Recipe Scraper Queue"
  [3]="Recipe Scraper Rate Limit"
  [4]="User Management"
  [5]="Notification Service"
  [6]="Meal Plan Management"
)

echo ""
echo "Initializing service databases..."
echo "----------------------------------------------"

# Build auth args
AUTH_ARGS=""
if [ -n "${REDIS_PASSWORD:-}" ]; then
  AUTH_ARGS="-a $REDIS_PASSWORD --no-auth-warning"
fi

# Sort scripts by name to ensure consistent order
for script in $(echo "${!INIT_SCRIPTS[@]}" | tr ' ' '\n' | sort); do
  db="${INIT_SCRIPTS[$script]}"
  service_name="${SERVICE_NAMES[$db]}"
  script_path="${SCRIPT_DIR}/${script}"

  if [[ -f "$script_path" ]]; then
    echo ""
    echo "DB $db: $service_name"
    echo "  Script: $script"

    # shellcheck disable=SC2086
    if result=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
        $AUTH_ARGS \
        -n "$db" \
        --eval "$script_path" 2>&1); then
      echo "  Status: SUCCESS"
    else
      echo "  Status: FAILED"
      echo "  Error: $result"
      exit 1
    fi
  else
    echo "WARNING: Script not found: $script_path"
  fi
done

echo ""
echo "----------------------------------------------"
echo "All service databases initialized successfully!"
echo "=============================================="

# Print summary
echo ""
echo "Database Summary:"
echo "  DB 0: Auth Service (OAuth2)"
echo "  DB 1: Recipe Scraper Cache"
echo "  DB 2: Recipe Scraper Queue"
echo "  DB 3: Recipe Scraper Rate Limit"
echo "  DB 4: User Management"
echo "  DB 5: Notification Service"
echo "  DB 6: Meal Plan Management"
echo "  DB 7-15: Reserved for future services"
