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
> `helm install session-database ./helm/session-database`

## Script Categories

### Core Container Scripts (Standalone Redis)

These scripts deploy a **standalone Redis instance** for development:

- **`deploy-container.sh`** - Deploy standalone Redis instance (uses `k8s/redis/standalone/`)
- **`start-container.sh`** - Start Redis deployment
- **`stop-container.sh`** - Stop Redis deployment (scale to 0)
- **`cleanup-container.sh`** - Clean up Redis with data preservation options
- **`get-container-status.sh`** - Check Redis health and status

> **Note**: For High Availability (HA) deployment with Redis Sentinel
> (master + replicas + sentinel), use **Helm with production values**:
> `helm install session-database ./helm/session-database --values ./helm/session-database/values-production.yaml`
>
> The HA manifests are available at `k8s/redis/ha/` for manual deployment.

#### Components Managed by Scripts

- Standalone Redis instance (single node with persistent storage)
- Token Cleanup CronJob (automated expired OAuth2 token removal)
- Core RBAC and service accounts
- Persistent volumes and storage

### Supporting Services Scripts (Monitoring & Security)

These scripts manage auxiliary services that support the core application:

- **`deploy-monitoring.sh`** - Deploy monitoring, alerting, and security
- **`cleanup-monitoring.sh`** - Clean up monitoring and security components

**Note**: Start/stop operations for monitoring services are not currently
implemented as separate scripts. Use `kubectl scale` commands directly or
redeploy as needed.

#### Supporting Components Managed

- **Monitoring Stack**: Prometheus, Grafana, Alertmanager, Redis Exporter
- **Security Policies**: Network policies, Pod Security Standards
- **Alerting Rules**: 15+ comprehensive Prometheus alerting rules
- **TLS Certificates**: Certificate generation and management jobs
- **Advanced RBAC**: Monitoring and security service accounts

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
NAMESPACE="session-database"
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
# 1. Deploy standalone Redis instance
./scripts/containerManagement/deploy-container.sh

# 2. Deploy monitoring and security
./scripts/containerManagement/deploy-monitoring.sh

# 3. Verify deployment
./scripts/containerManagement/get-container-status.sh

# Check monitoring services manually
kubectl get pods,svc -n session-database -l component=monitoring
```

### Maintenance Operations

```bash
# Stop services for maintenance
./scripts/containerManagement/stop-container.sh

# Perform maintenance tasks
# ...

# Restart services
./scripts/containerManagement/start-container.sh

# Note: Monitoring services don't have dedicated start/stop scripts
# Redeploy if needed: ./scripts/containerManagement/deploy-monitoring.sh
```

### Clean Removal

```bash
# Remove monitoring services first (proper dependency order)
./scripts/containerManagement/cleanup-monitoring.sh

# Remove core Redis cluster
./scripts/containerManagement/cleanup-container.sh
```

## Script Dependencies and Ordering

### Deployment Order (Critical)

1. **Core First**: `deploy-container.sh` must run before monitoring services
2. **Monitoring Second**: `deploy-monitoring.sh` depends on Redis cluster existing
3. **Verification Last**: Status checks can run independently after deployment

### Cleanup Order (Critical)

1. **Monitoring First**: `cleanup-monitoring.sh` removes monitoring of Redis
2. **Core Last**: `cleanup-container.sh` removes the Redis cluster being monitored

### Start/Stop Order

- **Start**: Core containers first, then monitoring services (if using
  separate deployments)
- **Stop**: Core containers can be stopped independently; monitoring services
  typically remain running

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

### Core Status Checks (Standalone Mode)

- Redis instance availability
- Session cleanup job execution history
- Persistent volume availability and usage

> **Note**: For HA deployments (via Helm), additional checks apply:
> Redis replica count, replication lag, and Sentinel quorum status.

### Supporting Services Status Checks

- Prometheus scrape target health
- Grafana dashboard availability
- Alertmanager rule evaluation and firing
- Network policy enforcement
- TLS certificate validity
- Monitoring RBAC permissions

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
./scripts/containerManagement/deploy-monitoring.sh

# Check everything is working
./scripts/containerManagement/get-container-status.sh
kubectl get pods,svc -n session-database
```

### Production Deployment

```bash
# Ensure environment is configured
cp .env.example .env
# Edit .env with production passwords

# Deploy with validation
./scripts/containerManagement/deploy-container.sh
./scripts/containerManagement/deploy-monitoring.sh

# Verify deployment
./scripts/containerManagement/get-container-status.sh
kubectl get pods,svc -n session-database -l component=monitoring
```

### Troubleshooting

```bash
# Check status of all components
./scripts/containerManagement/get-container-status.sh

# Check monitoring services
kubectl get pods,svc -n session-database -l component=monitoring

# Common troubleshooting
kubectl get pods -n session-database
kubectl describe pods -n session-database
kubectl logs -n session-database -l app.kubernetes.io/name=session-database
```

This documentation ensures consistent usage patterns across the distributed
system and provides a clear migration path to the SystemManagement project.
