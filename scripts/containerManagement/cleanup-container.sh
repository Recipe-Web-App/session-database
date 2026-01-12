#!/bin/bash
# scripts/containerManagement/cleanup-container.sh
# Cleans up Redis database Helm deployment

set -euo pipefail

NAMESPACE="redis-database"
RELEASE_NAME="redis-database"
IMAGE_NAME="redis-database"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

print_separator "="
echo "Checking Minikube status..."
print_separator "-"

if ! minikube status >/dev/null 2>&1; then
  echo "Warning: Minikube is not running. Starting Minikube..."
  if ! minikube start; then
    echo "Failed to start Minikube. Exiting."
    exit 1
  fi
else
  echo "Minikube is already running."
fi

print_separator "="
echo "Removing hostname from /etc/hosts..."
print_separator "-"

HOSTNAME="redis-database.local"
sed -i "/${HOSTNAME}/d" /etc/hosts
echo "Removed ${HOSTNAME} from /etc/hosts"

print_separator "="
echo "Uninstalling Helm release '${RELEASE_NAME}'..."
print_separator "-"

if helm status "$RELEASE_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  helm uninstall "$RELEASE_NAME" --namespace "$NAMESPACE"
  echo "Helm release '${RELEASE_NAME}' uninstalled."
else
  echo "Helm release '${RELEASE_NAME}' not found. Skipping."
fi

print_separator "="
read -r -p "Do you want to delete PersistentVolumeClaims (PVCs)? This will delete all stored data! (y/N): " del_pvc
print_separator "-"

if [[ "$del_pvc" =~ ^[Yy]$ ]]; then
  kubectl delete pvc -l app.kubernetes.io/name=redis-database -n "$NAMESPACE" --ignore-not-found
  kubectl delete pv -l app.kubernetes.io/name=redis-database --ignore-not-found
  echo "PVCs deleted."
else
  echo "PVCs retained."
fi

print_separator "="
echo "Removing Docker image '${FULL_IMAGE_NAME}' from Minikube..."
print_separator "-"

eval "$(minikube docker-env)"
docker rmi -f "$FULL_IMAGE_NAME" || echo "Image not found or already removed."

print_separator "="
read -r -p "Do you want to stop (shut down) Minikube now? (y/N): " stop_mk
print_separator "-"

if [[ "$stop_mk" =~ ^[Yy]$ ]]; then
  echo "Stopping Minikube..."
  minikube stop
  echo "Minikube stopped."
else
  echo "Minikube left running."
fi

print_separator "="
echo "Cleanup complete."
print_separator "="
