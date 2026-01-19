#!/bin/bash
# scripts/containerManagement/deploy-container.sh
# Deploys Redis database using Kustomize

set -euo pipefail

# Default to development environment
ENV="${1:-development}"
NAMESPACE="redis-database"
IMAGE_NAME="redis-database"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

print_separator "="
echo "Deploying to environment: ${ENV}"
print_separator "-"

# Validate environment
if [[ ! -d "${PROJECT_ROOT}/k8s/overlays/${ENV}" ]]; then
  echo "Error: Unknown environment '${ENV}'"
  echo "Available environments: development, staging, production"
  exit 1
fi

print_separator "="
echo "Checking prerequisites..."
print_separator "-"
env_status=true

if ! command -v minikube >/dev/null 2>&1; then
  echo "Minikube is not installed. Please install it first."
  env_status=false
else
  echo "Minikube is installed."
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is not installed. Please install it first."
  env_status=false
else
  echo "kubectl is installed."
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed. Please install it first."
  env_status=false
else
  echo "Docker is installed."
fi

if ! $env_status; then
  echo "Please resolve the above issues before proceeding."
  exit 1
fi

if ! minikube status >/dev/null 2>&1; then
  print_separator "-"
  echo "Starting Minikube..."
  minikube start

  if ! minikube addons list | grep -q 'ingress *enabled'; then
    echo "Enabling Minikube ingress addon..."
    minikube addons enable ingress
  fi
  echo "Minikube started."
else
  echo "Minikube is already running."
fi

print_separator "="
echo "Verifying environment file exists..."
print_separator "-"

ENV_FILE="${PROJECT_ROOT}/k8s/overlays/${ENV}/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "Error: Environment file not found: ${ENV_FILE}"
  echo "Kustomize secretGenerator requires this file."
  exit 1
fi
echo "Environment file found: ${ENV_FILE}"

print_separator "="
echo "Ensuring namespace '${NAMESPACE}' exists..."
print_separator "-"

if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "'$NAMESPACE' namespace already exists."
else
  kubectl create namespace "$NAMESPACE"
  echo "'$NAMESPACE' namespace created."
fi

print_separator "="
echo "Building Docker image: ${FULL_IMAGE_NAME} (inside Minikube Docker daemon)"
print_separator '-'

eval "$(minikube docker-env)"
docker build -t "$FULL_IMAGE_NAME" "${PROJECT_ROOT}"
echo "Docker image '${FULL_IMAGE_NAME}' built successfully."

print_separator "="
echo "Deploying Redis with Kustomize (${ENV} overlay)..."
print_separator "-"

kubectl apply -k "${PROJECT_ROOT}/k8s/overlays/${ENV}"
echo "Kustomize deployment applied."

print_separator "="
echo "Waiting for pods to be ready..."
print_separator "-"

kubectl wait --namespace="$NAMESPACE" \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/name=redis-database \
  --timeout=120s || {
  echo "Warning: Pods not ready within timeout. Checking status..."
  kubectl get pods -n "$NAMESPACE"
}

echo "Pods are ready."

print_separator "="
echo "Configuring external access..."
print_separator "-"

MINIKUBE_IP=$(minikube ip)
# Get the allocated NodePort
NODE_PORT=$(kubectl get svc redis-database-master-service -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")

if [ -n "$MINIKUBE_IP" ] && [ -n "$NODE_PORT" ]; then
  echo "Minikube IP: ${MINIKUBE_IP}"
  echo "NodePort: ${NODE_PORT}"
  LOCAL_HOSTNAME="redis-database.local"

  # Update /etc/hosts if we have permission
  if [ -w /etc/hosts ]; then
    sed -i "/${LOCAL_HOSTNAME}/d" /etc/hosts
    echo "${MINIKUBE_IP} ${LOCAL_HOSTNAME}" >> /etc/hosts
    echo "Added ${LOCAL_HOSTNAME} -> ${MINIKUBE_IP} to /etc/hosts"
  else
    echo "Note: Cannot update /etc/hosts (no write permission)"
    echo "Add manually: ${MINIKUBE_IP} ${LOCAL_HOSTNAME}"
  fi
else
  echo "Warning: Could not determine external access details"
fi

print_separator "="
echo "Redis is up and running in namespace '$NAMESPACE'."
print_separator "-"
echo "Access info:"
echo "  Internal Host: redis-database-master-service.${NAMESPACE}.svc.cluster.local"
if [ -n "$MINIKUBE_IP" ] && [ -n "$NODE_PORT" ]; then
  echo "  Minikube IP: $MINIKUBE_IP"
  echo "  NodePort: $NODE_PORT"
  echo "  Hostname: redis-database.local"
  echo "  External Access: redis-cli -h redis-database.local -p $NODE_PORT -a \$REDIS_PASSWORD"
else
  echo "  External Access: (run 'minikube ip' and 'kubectl get svc -n $NAMESPACE' to check)"
fi
echo "  Internal Port: 6379"
print_separator "="
