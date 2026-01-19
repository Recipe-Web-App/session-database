# Container Management Scripts

This directory contains deployment and management scripts that follow
consistent patterns across the distributed system architecture. These scripts
are designed for eventual migration to a SystemManagement project.

## Overview

The containerManagement scripts provide a consistent interface for deploying,
managing, and monitoring containerized services. They follow established
patterns that ensure compatibility across the entire distributed system.

> **Important**: These scripts are designed for **Minikube** local development
> environments. For other Kubernetes distributions (Kind, k3s, microk8s, cloud
> providers), use **Helm deployment** instead:
> `helm install redis-database ./helm/redis-database`

## Script Categories

### Core Container Scripts

These scripts deploy Redis via Helm for development:

- **`deploy-container.sh`** - Deploy Redis via Helm (handles minikube setup, Docker build, Helm install)
- **`start-container.sh`** - Start Redis deployment
- **`stop-container.sh`** - Stop Redis deployment (scale to 0)
- **`cleanup-container.sh`** - Clean up Redis with Helm uninstall and data preservation options
- **`get-container-status.sh`** - Check Redis health and status

> **Note**: For High Availability (HA) deployment with Redis Sentinel
> (master + replicas + sentinel), use **Helm with production values**:
> `helm install redis-database ./helm/redis-database --values ./helm/redis-database/values-production.yaml`

#### Components Managed by Scripts

- Redis Sentinel HA cluster (master, replicas, sentinel)
- Token Cleanup CronJob (automated expired OAuth2 token removal)
- Core RBAC and service accounts
- Persistent volumes and storage

## Consistent Style Patterns

All scripts in the containerManagement directory follow these established
patterns for compatibility with the distributed system:

### 1. Script Header Pattern

```bash
#!/bin/bash
# scripts/containerManagement/[script-name].sh

set -euo pipefail
```

### 2. Variable Naming Convention

```bash
NAMESPACE="redis-database"
DEPLOYMENT_NAME="redis-master"
SERVICE_NAME="redis-master-service"
```

- All CAPS for constants
- Descriptive, service-specific naming
- Clear component identification

### 3. Terminal UI Pattern

```bash
# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}
```

### 4. Output Format Pattern

```bash
print_separator "="
echo "🔄 [Action description with emoji]..."
print_separator "-"
[commands and logic]
print_separator "="
echo "✅ [Success message]"
print_separator "="
```

### 5. Error Handling

- `set -euo pipefail` for strict error handling
- Clear, actionable error messages
- Graceful failure with cleanup when possible
- Exit codes that indicate specific failure types

## Deployment Workflows

### Full Deployment Workflow

```bash
# Deploy Redis via Helm
./scripts/containerManagement/deploy-container.sh

# Verify deployment
./scripts/containerManagement/get-container-status.sh
```

### Maintenance Operations

```bash
# Stop services for maintenance
./scripts/containerManagement/stop-container.sh

# Perform maintenance tasks
# ...

# Restart services
./scripts/containerManagement/start-container.sh
```

### Clean Removal

```bash
# Remove Redis cluster
./scripts/containerManagement/cleanup-container.sh
```

## Environment Variable Handling

All scripts follow consistent environment variable patterns:

### Required Variables

```bash
# Core Redis Authentication
REDIS_PASSWORD=your-secure-redis-password
SENTINEL_PASSWORD=your-secure-sentinel-password

# ACL User Passwords (role-based access)
APP_PASSWORD=your-app-password          # Application access
MONITOR_PASSWORD=your-monitor-password  # Prometheus monitoring
CLEANUP_PASSWORD=your-cleanup-password  # Cleanup job access
BACKUP_PASSWORD=your-backup-password    # Backup operations
```

### Environment Loading Pattern

```bash
if [ -f .env ]; then
  set -o allexport
  source .env
  set +o allexport
  echo "✅ Loaded environment variables from .env"
else
  echo "⚠️  No .env file found. Using defaults."
fi
```

## Status and Health Checking

### Core Status Checks

- Redis instance availability
- Redis replica count, replication lag, and Sentinel quorum status
- Session cleanup job execution history
- Persistent volume availability and usage

## Error Handling and Recovery

### Common Error Scenarios

1. **Insufficient Resources**: Clear guidance on resource requirements
2. **Network Connectivity**: DNS resolution and service discovery issues
3. **Authentication Failures**: Password validation and secret management
4. **Storage Issues**: PVC availability and permissions
5. **Version Compatibility**: Kubernetes version requirements

### Recovery Procedures

- Automatic retry for transient failures
- Clear rollback procedures for failed deployments
- Data preservation during cleanup operations
- Health check validation after recovery

## Migration to SystemManagement Project

These scripts are designed for easy migration to a centralized SystemManagement project:

### Standardized Patterns

- Consistent variable naming across all services
- Identical output formatting and user experience
- Standardized error handling and logging
- Compatible deployment workflows

### Reusable Components

- `print_separator()` function in all scripts
- Common environment variable loading
- Standardized kubectl operation patterns
- Consistent status checking formats

### Documentation Structure

- Self-documenting script headers
- Inline comments following established patterns
- Consistent usage examples
- Error message standardization

## Usage Examples

### Development Deployment

```bash
# Quick development setup
./scripts/containerManagement/deploy-container.sh

# Check everything is working
./scripts/containerManagement/get-container-status.sh
kubectl get pods,svc -n redis-database
```

### Production Deployment

For production, use Helm directly:

```bash
helm install redis-database ./helm/redis-database \
  --namespace redis-database --create-namespace \
  --values ./helm/redis-database/values-production.yaml
```

### Troubleshooting

```bash
# Check status of all components
./scripts/containerManagement/get-container-status.sh

# Common troubleshooting
kubectl get pods -n redis-database
kubectl describe pods -n redis-database
kubectl logs -n redis-database -l app.kubernetes.io/name=redis-database
```

This documentation ensures consistent usage patterns across the distributed
system and provides a clear migration path to the SystemManagement project.
