#!/bin/bash
# scripts/containerManagement/cleanup-monitoring.sh

set -euo pipefail

NAMESPACE="session-database"

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

print_separator "="
echo "🧹 Cleaning up monitoring stack..."
print_separator "-"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
  echo "❌ kubectl is not installed. Please install it first."
  exit 1
fi

print_separator "="
echo "⚠️  WARNING: This will delete all monitoring resources"
print_separator "-"
echo "This includes:"
echo "  • Prometheus deployment, service, and PVC"
echo "  • Grafana deployment, service, and PVC"
echo "  • Redis Exporter deployment and service"
echo "  • All monitoring ConfigMaps"
echo "  • Falco DaemonSet (cluster-wide)"
echo ""
echo "⚠️  This will permanently delete monitoring data!"

read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "❌ Cleanup cancelled."
  exit 1
fi



print_separator "="
echo "📊 Removing Prometheus..."
print_separator "-"

kubectl delete -f k8s/monitoring/prometheus-configmap.yaml --ignore-not-found
kubectl delete -f k8s/monitoring/prometheus-pvc.yaml --ignore-not-found
kubectl delete -f k8s/monitoring/prometheus-deployment.yaml --ignore-not-found
kubectl delete -f k8s/monitoring/prometheus-service.yaml --ignore-not-found
echo "✅ Prometheus removed."

print_separator "="
echo "🔍 Removing Redis Exporter..."
print_separator "-"

kubectl delete -f k8s/monitoring/redis-exporter-deployment.yaml --ignore-not-found
kubectl delete -f k8s/monitoring/redis-exporter-service.yaml --ignore-not-found
echo "✅ Redis Exporter removed."

print_separator "="
echo "📈 Removing Grafana..."
print_separator "-"

kubectl delete -f k8s/monitoring/grafana-pvc.yaml --ignore-not-found
kubectl delete -f k8s/monitoring/grafana-deployment.yaml --ignore-not-found
kubectl delete -f k8s/monitoring/grafana-service.yaml --ignore-not-found
kubectl delete -f k8s/monitoring/grafana-dashboards-config.yaml --ignore-not-found
kubectl delete -f k8s/monitoring/grafana-datasources-config.yaml --ignore-not-found
echo "✅ Grafana removed."

print_separator "="
echo "🌐 Removing Ingress..."
print_separator "-"

kubectl delete -f k8s/monitoring/ingress.yaml --ignore-not-found
echo "✅ Ingress removed."

print_separator "="
echo "🧹 Cleaning up any remaining resources..."
print_separator "-"

# Clean up any orphaned resources
kubectl delete pvc -l app=prometheus -n "$NAMESPACE" --ignore-not-found
kubectl delete pvc -l app=grafana -n "$NAMESPACE" --ignore-not-found
kubectl delete configmap -l grafana_dashboard -n "$NAMESPACE" --ignore-not-found
kubectl delete configmap -l grafana_datasource -n "$NAMESPACE" --ignore-not-found

print_separator "="
echo "✅ Monitoring stack cleanup completed!"
print_separator "-"

echo "📋 Cleaned up resources:"
echo "  • Prometheus deployment, service, PVC, and ConfigMap"
echo "  • Grafana deployment, service, PVC, and ConfigMaps"
echo "  • Redis Exporter deployment and service"
print_separator "="
