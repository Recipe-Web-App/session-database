#!/bin/bash
# scripts/containerManagement/deploy-monitoring.sh

set -euo pipefail

NAMESPACE="redis-database"

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

print_separator "="
echo "🔧 Setting up monitoring environment..."
print_separator "-"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
  echo "❌ kubectl is not installed. Please install it first."
  exit 1
else
  echo "✅ kubectl is installed."
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
echo "📊 Deploying Prometheus..."
print_separator "-"

kubectl apply -f k8s/prometheus/prometheus-configmap.yaml
kubectl apply -f k8s/prometheus/prometheus-pvc.yaml
kubectl apply -f k8s/prometheus/prometheus-deployment.yaml
kubectl apply -f k8s/prometheus/prometheus-service.yaml
echo "✅ Prometheus deployed successfully."

print_separator "="
echo "🔍 Deploying Redis Exporter..."
print_separator "-"

kubectl apply -f k8s/prometheus/redis-exporter/deployment.yaml
kubectl apply -f k8s/prometheus/redis-exporter/service.yaml
echo "✅ Redis Exporter deployed successfully."

print_separator "="
echo "📈 Deploying Grafana..."
print_separator "-"

kubectl apply -f k8s/grafana/grafana-dashboards-config.yaml
kubectl apply -f k8s/grafana/grafana-datasources-config.yaml
kubectl apply -f k8s/grafana/grafana-pvc.yaml
kubectl apply -f k8s/grafana/grafana-deployment.yaml
kubectl apply -f k8s/grafana/grafana-service.yaml
echo "✅ Grafana deployed successfully."



print_separator "="
echo "⏳ Waiting for deployments to be ready..."
print_separator "-"

kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n "$NAMESPACE"
kubectl wait --for=condition=available --timeout=300s deployment/redis-exporter -n "$NAMESPACE"
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n "$NAMESPACE"

print_separator "="
echo "🌐 Deploying Ingress for monitoring..."
print_separator "-"

kubectl apply -f k8s/shared/ingress.yaml
echo "✅ Ingress deployed successfully."

print_separator "="
echo "🔗 Setting up access URLs..."
print_separator "-"

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)
HOSTS_ENTRY="$MINIKUBE_IP prometheus.local grafana.local"

echo "📊 Prometheus will be available at: http://prometheus.local"
echo "📈 Grafana will be available at: http://grafana.local (admin/admin)"
echo ""

# Update /etc/hosts automatically
echo "🌐 Updating /etc/hosts for monitoring access..."
if grep -q "prometheus.local" /etc/hosts; then
  echo "⚠️  Hosts entry already exists. Updating..."
  sed -i '/prometheus.local/d' /etc/hosts
fi
echo "$HOSTS_ENTRY" >> /etc/hosts
echo "✅ /etc/hosts updated successfully!"

print_separator "="
echo "✅ Monitoring stack deployed successfully in namespace '$NAMESPACE'."
print_separator "-"

print_separator "="
echo "📡 Access info:"
echo "  Prometheus: http://prometheus.local"
echo "  Grafana:    http://grafana.local (admin/admin)"
print_separator "="
