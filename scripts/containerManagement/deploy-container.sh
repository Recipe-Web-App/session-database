#!/bin/bash
# scripts/containerManagement/deploy-container.sh
# Deploys Redis database using Helm chart

set -euo pipefail

NAMESPACE="redis-database"
RELEASE_NAME="redis-database"
CHART_PATH="./helm/redis-database"
VALUES_FILE="./helm/redis-database/values-local.yaml"
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

if ! command -v helm >/dev/null 2>&1; then
  echo "Helm is not installed. Please install it first."
  env_status=false
else
  echo "Helm is installed."
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
echo "Ensuring namespace '${NAMESPACE}' exists..."
print_separator "-"

if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "'$NAMESPACE' namespace already exists."
else
  kubectl create namespace "$NAMESPACE"
  echo "'$NAMESPACE' namespace created."
fi

print_separator "="
echo "Loading environment variables from .env file (if present)..."
print_separator "-"

if [ -f .env ]; then
  set -o allexport
  # Capture env before
  BEFORE_ENV=$(mktemp)
  AFTER_ENV=$(mktemp)
  env | cut -d= -f1 | sort > "$BEFORE_ENV"
  source .env
  # Capture env after
  env | cut -d= -f1 | sort > "$AFTER_ENV"
  # Show newly loaded/changed variables
  echo "Loaded variables from .env:"
  comm -13 "$BEFORE_ENV" "$AFTER_ENV"
  rm -f "$BEFORE_ENV" "$AFTER_ENV"
  set +o allexport
fi

print_separator "="
echo "Building Docker image: ${FULL_IMAGE_NAME} (inside Minikube Docker daemon)"
print_separator '-'

eval "$(minikube docker-env)"
docker build -t "$FULL_IMAGE_NAME" .
echo "Docker image '${FULL_IMAGE_NAME}' built successfully."

print_separator "="
echo "Deploying Redis with Helm..."
print_separator "-"

# Build Helm set flags from environment variables
HELM_SET_FLAGS=""

# Set image tag
HELM_SET_FLAGS="$HELM_SET_FLAGS --set image.tag=${IMAGE_TAG}"

# Set passwords from .env if available
if [ -n "${REDIS_PASSWORD:-}" ]; then
  HELM_SET_FLAGS="$HELM_SET_FLAGS --set redis.auth.password=${REDIS_PASSWORD}"
fi

if [ -n "${SENTINEL_PASSWORD:-}" ]; then
  HELM_SET_FLAGS="$HELM_SET_FLAGS --set redis.auth.sentinel.password=${SENTINEL_PASSWORD}"
fi

# Set NodePort values from .env if available
if [ -n "${REDIS_NODEPORT:-}" ]; then
  HELM_SET_FLAGS="$HELM_SET_FLAGS --set service.nodePort.port=${REDIS_NODEPORT}"
fi

if [ -n "${SENTINEL_NODEPORT:-}" ]; then
  HELM_SET_FLAGS="$HELM_SET_FLAGS --set service.sentinel.nodePort.port=${SENTINEL_NODEPORT}"
fi

# Deploy using Helm
# shellcheck disable=SC2086
helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
  --namespace "$NAMESPACE" \
  --values "$VALUES_FILE" \
  $HELM_SET_FLAGS \
  --wait \
  --timeout 5m

echo "Helm deployment completed successfully."

print_separator "="
echo "Waiting for pods to be ready..."
print_separator "-"

kubectl wait --namespace="$NAMESPACE" \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/name=redis-database \
  --timeout=90s

echo "Pods are ready."

print_separator "="
echo "Configuring external access..."
print_separator "-"

MINIKUBE_IP=$(minikube ip)
NODE_PORT=${REDIS_NODEPORT:-30379}

if [ -n "$MINIKUBE_IP" ]; then
  echo "Minikube IP: ${MINIKUBE_IP}"
  echo "NodePort: ${NODE_PORT}"
  LOCAL_HOSTNAME="redis-database.local"
  sed -i "/${LOCAL_HOSTNAME}/d" /etc/hosts
  echo "${MINIKUBE_IP} ${LOCAL_HOSTNAME}" >> /etc/hosts
  echo "Added ${LOCAL_HOSTNAME} -> ${MINIKUBE_IP} to /etc/hosts"
else
  echo "Warning: Could not determine Minikube IP"
fi

print_separator "="
echo "Redis is up and running in namespace '$NAMESPACE'."
print_separator "-"
echo "Access info:"
echo "  Internal Host: redis-database-master.$NAMESPACE.svc.cluster.local"
if [ -n "$MINIKUBE_IP" ]; then
  echo "  Minikube IP: $MINIKUBE_IP"
  echo "  NodePort: $NODE_PORT"
  echo "  Hostname: redis-database.local"
  echo "  External Access: redis-cli -h redis-database.local -p $NODE_PORT -a \$REDIS_PASSWORD"
else
  echo "  External Access: (run 'minikube ip' and 'kubectl get svc -n $NAMESPACE' to check)"
fi
echo "  Internal Port: 6379"
print_separator "="
