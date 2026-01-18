#!/bin/bash
# scripts/containerManagement/stop-container.sh

set -euo pipefail

NAMESPACE="redis-database"
DEPLOYMENT="redis-database"

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

print_separator "="
echo "🛑 Scaling deployment '$DEPLOYMENT' in namespace '$NAMESPACE' to 0 replicas..."
print_separator "-"

kubectl scale deployment "$DEPLOYMENT" --replicas=0 -n "$NAMESPACE"

print_separator "="
echo "✅ Deployment stopped."
print_separator "="
