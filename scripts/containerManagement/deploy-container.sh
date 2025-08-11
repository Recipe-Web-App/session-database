#!/bin/bash
# scripts/containerManagement/deploy-container.sh

set -euo pipefail

NAMESPACE="session-database"
CONFIG_DIR="k8s"
SECRET_NAME="session-database-secret" # pragma: allowlist secret
MOUNT_PATH="/mnt/session-database"
LOCAL_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
MOUNT_PORT=8787
MOUNT_CMD="minikube mount ${LOCAL_PATH}:${MOUNT_PATH} --port=${MOUNT_PORT}"
IMAGE_NAME="session-database"
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
echo "🔧 Setting up Minikube environment..."
print_separator "-"
env_status=true
if ! command -v minikube >/dev/null 2>&1; then
  echo "❌ Minikube is not installed. Please install it first."
  env_status=false
else
  echo "✅ Minikube is installed."
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "❌ kubectl is not installed. Please install it first."
  env_status=false
else
  echo "✅ kubectl is installed."
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Docker is not installed. Please install it first."
  env_status=false
else
  echo "✅ Docker is installed."
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ jq is not installed. Please install it first."
  env_status=false
else
  echo "✅ jq is installed."
fi
if ! $env_status; then
  echo "Please resolve the above issues before proceeding."
  exit 1
fi

if ! minikube status >/dev/null 2>&1; then
  print_separator "-"
  echo "🚀 Starting Minikube..."
  minikube start

  if ! minikube addons list | grep -q 'ingress *enabled'; then
    echo "🔌 Enabling Minikube ingress addon..."
    minikube addons enable ingress
    echo "✅ Minikube started."
  fi
else
  echo "✅ Minikube is already running."
fi

print_separator "="
echo "📂 Ensuring namespace '${NAMESPACE}' exists..."
print_separator "-"

if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "✅ '$NAMESPACE' namespace already exists."
else
  kubectl create namespace "$NAMESPACE"
  echo "✅ '$NAMESPACE' namespace created."
fi

print_separator "="
echo "🔧 Loading environment variables from .env file (if present)..."
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
  echo "✅ Loaded variables from .env:"
  comm -13 "$BEFORE_ENV" "$AFTER_ENV"
  rm -f "$BEFORE_ENV" "$AFTER_ENV"
  set +o allexport
fi

print_separator "="
echo "🐳 Building Docker image: ${FULL_IMAGE_NAME} (inside Minikube Docker daemon)"
print_separator '-'

eval "$(minikube docker-env)"
docker build -t "$FULL_IMAGE_NAME" .
echo "✅ Docker image '${FULL_IMAGE_NAME}' built successfully."

print_separator "="
echo "⚙️ Creating/Updating ConfigMap from env..."
print_separator "-"

envsubst < "${CONFIG_DIR}/templates/configmap-template.yaml" | kubectl apply -f -

print_separator "="
echo "🔐 Creating/updating Secret..."
print_separator "-"

kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE" --ignore-not-found
envsubst < "${CONFIG_DIR}/templates/secret-template.yaml" | kubectl apply -f -

print_separator "="
echo "💾 Applying PersistentVolumeClaim..."
print_separator "-"

kubectl apply -f "${CONFIG_DIR}/redis/standalone/pvc.yaml"

kubectl get pv -o json | jq -r '.items[] | select(.spec.claimRef.namespace=="session-database") | .metadata.name' | \
  xargs -I{} kubectl label pv {} app=session-database --overwrite

print_separator "="
echo "📦 Deploying Redis container..."
print_separator "-"

kubectl apply -f "${CONFIG_DIR}/redis/standalone/deployment.yaml"

print_separator "="
echo "🌐 Exposing Redis via ClusterIP Service..."
print_separator "-"

kubectl apply -f "${CONFIG_DIR}/redis/standalone/service.yaml"

kubectl wait --namespace="$NAMESPACE" \
  --for=condition=Ready pod \
  --selector=app=session-database,component!=initialization \
  --timeout=90s

print_separator "="
echo "🔧 Running Redis Lua script initialization..."
print_separator "-"

# Clean up any previous init jobs
kubectl delete job redis-lua-init -n "$NAMESPACE" --ignore-not-found

# Run the initialization job
kubectl apply -f "${CONFIG_DIR}/redis/standalone/init-job.yaml"

# Wait for the job to complete
if kubectl get job redis-lua-init -n "$NAMESPACE" -o jsonpath='{.status.conditions[0].type}' 2>/dev/null | grep -q "Complete"; then
  echo "✅ Init job already complete"
else
  kubectl wait --namespace="$NAMESPACE" \
    --for=condition=Complete job/redis-lua-init \
    --timeout=60s
fi

echo "✅ Lua scripts initialized successfully"

print_separator "="
echo "✅ Redis is up and running with session management in namespace '$NAMESPACE'."
print_separator "-"

if ! pgrep -f "$MOUNT_CMD" > /dev/null; then
  echo "🔗 Starting Minikube mount on port ${MOUNT_PORT}..."
  nohup minikube mount "${LOCAL_PATH}:${MOUNT_PATH}" --port="${MOUNT_PORT}" > /tmp/minikube-mount.log 2>&1 &
  echo "⏳ Waiting for Minikube mount to be ready..."
  sleep 5
else
  echo "✅ Minikube mount already running on port ${MOUNT_PORT}."
fi

POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=session-database -o jsonpath="{.items[0].metadata.name}")

print_separator "="
echo "📡 Access info:"
echo "  Pod: $POD_NAME"
echo "  Host: session-database.$NAMESPACE.svc.cluster.local"
echo "  Port: 6379"
echo "  Database: Redis"
print_separator "="
