#!/bin/bash
# scripts/containerManagement/cleanup-container.sh
# Cleans up Redis database Kustomize deployment

set -euo pipefail

NAMESPACE="redis-database"
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

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "Namespace '$NAMESPACE' does not exist. Nothing to clean up."
else
  print_separator "="
  echo "Deleting workloads (StatefulSets, Deployments)..."
  print_separator "-"

  # Delete workloads FIRST - this releases PVC claims
  kubectl delete statefulset --all -n "$NAMESPACE" --ignore-not-found --timeout=60s 2>/dev/null || true
  kubectl delete deployment --all -n "$NAMESPACE" --ignore-not-found --timeout=60s 2>/dev/null || true

  print_separator "="
  echo "Waiting for pods to terminate..."
  print_separator "-"

  # Wait for pods to actually terminate (max 60 seconds)
  timeout=60
  while [ $timeout -gt 0 ]; do
    pod_count=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    if [ "$pod_count" -eq 0 ]; then
      echo "All pods terminated."
      break
    fi
    echo "Waiting for $pod_count pod(s) to terminate... ($timeout seconds remaining)"
    sleep 5
    timeout=$((timeout - 5))
  done

  if [ $timeout -le 0 ]; then
    echo "Warning: Pods did not terminate within timeout. Force deleting..."
    kubectl delete pods --all -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
    sleep 2
  fi

  print_separator "="
  read -r -p "Do you want to delete PersistentVolumeClaims (PVCs)? This will delete all stored data! (y/N): " del_pvc
  print_separator "-"

  if [[ "$del_pvc" =~ ^[Yy]$ ]]; then
    echo "Deleting PVCs..."
    kubectl delete pvc --all -n "$NAMESPACE" --ignore-not-found --timeout=30s 2>/dev/null || true
    echo "PVCs deleted."
  else
    echo "PVCs retained."
  fi

  print_separator "="
  echo "Deleting remaining resources (services, configmaps, secrets)..."
  print_separator "-"

  kubectl delete service --all -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
  kubectl delete configmap --all -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
  kubectl delete secret --all -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
  kubectl delete serviceaccount --all -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true

  print_separator "="
  read -r -p "Do you want to delete the namespace '$NAMESPACE'? (y/N): " del_ns
  print_separator "-"

  if [[ "$del_ns" =~ ^[Yy]$ ]]; then
    echo "Deleting namespace..."
    kubectl delete namespace "$NAMESPACE" --timeout=60s 2>/dev/null || true
    echo "Namespace deleted."
  else
    echo "Namespace retained."
  fi
fi

print_separator "="
echo "Removing hostname from /etc/hosts..."
print_separator "-"

HOSTNAME="redis-database.local"
if [ -w /etc/hosts ]; then
  sed -i "/${HOSTNAME}/d" /etc/hosts
  echo "Removed ${HOSTNAME} from /etc/hosts"
else
  echo "Note: Cannot update /etc/hosts (no write permission)"
  echo "Remove manually: grep -v '${HOSTNAME}' /etc/hosts"
fi

print_separator "="
read -r -p "Do you want to remove the Docker image '${FULL_IMAGE_NAME}' from Minikube? (y/N): " del_img
print_separator "-"

if [[ "$del_img" =~ ^[Yy]$ ]]; then
  eval "$(minikube docker-env)"
  docker rmi -f "$FULL_IMAGE_NAME" 2>/dev/null || echo "Image not found or already removed."
  echo "Docker image removed."
else
  echo "Docker image retained."
fi

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
