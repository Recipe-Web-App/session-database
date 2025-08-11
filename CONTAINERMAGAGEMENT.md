# Container Management Scripts

This directory contains deployment and management scripts that follow consistent patterns across the distributed system architecture. These scripts are designed for eventual migration to a SystemManagement project.

## Overview

The containerManagement scripts provide a consistent interface for deploying, managing, and monitoring containerized services. They follow established patterns that ensure compatibility across the entire distributed system.

## Script Categories

### Core Container Scripts (Redis Cluster)

These scripts manage the core Redis high-availability cluster:

- **`deploy-container.sh`** - Deploy Redis HA cluster with Sentinel
- **`start-container.sh`** - Start Redis cluster components
- **`stop-container.sh`** - Stop Redis cluster components
- **`cleanup-container.sh`** - Clean up Redis cluster with data preservation
- **`get-container-status.sh`** - Check Redis cluster health and status

#### Components Managed:
- Redis Master (primary instance with persistent storage)
- Redis Replicas (2-3 read replicas for scaling and failover)
- Redis Sentinel (3-node cluster for automatic failover)
- Session Cleanup CronJob (automated expired session removal)
- Core RBAC and service accounts
- Persistent volumes and storage

### Supporting Services Scripts (Monitoring & Security)

These scripts manage auxiliary services that support the core application:

- **`deploy-supporting-services.sh`** - Deploy monitoring, alerting, and security
- **`start-supporting-services.sh`** - Start supporting services
- **`stop-supporting-services.sh`** - Stop supporting services
- **`cleanup-supporting-services.sh`** - Clean up supporting services
- **`get-supporting-services-status.sh`** - Check supporting services status

#### Components Managed:
- **Monitoring Stack**: Prometheus, Grafana, Alertmanager, Redis Exporter
- **Security Policies**: Network policies, Pod Security Standards
- **Alerting Rules**: 15+ comprehensive Prometheus alerting rules
- **TLS Certificates**: Certificate generation and management jobs
- **Advanced RBAC**: Monitoring and security service accounts

## Consistent Style Patterns

All scripts in the containerManagement directory follow these established patterns for compatibility with the distributed system:

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
# 1. Deploy core Redis HA cluster
./scripts/containerManagement/deploy-container.sh

# 2. Deploy monitoring and security
./scripts/containerManagement/deploy-supporting-services.sh

# 3. Verify deployment
./scripts/containerManagement/get-container-status.sh
./scripts/containerManagement/get-supporting-services-status.sh
```

### Maintenance Operations
```bash
# Stop services for maintenance
./scripts/containerManagement/stop-supporting-services.sh
./scripts/containerManagement/stop-container.sh

# Perform maintenance tasks
# ...

# Restart services
./scripts/containerManagement/start-container.sh
./scripts/containerManagement/start-supporting-services.sh
```

### Clean Removal
```bash
# Remove supporting services first (proper dependency order)
./scripts/containerManagement/cleanup-supporting-services.sh

# Remove core Redis cluster
./scripts/containerManagement/cleanup-container.sh
```

## Script Dependencies and Ordering

### Deployment Order (Critical)
1. **Core First**: `deploy-container.sh` must run before supporting services
2. **Supporting Second**: `deploy-supporting-services.sh` depends on Redis cluster existing
3. **Verification Last**: Status checks can run independently after deployment

### Cleanup Order (Critical)
1. **Supporting First**: `cleanup-supporting-services.sh` removes monitoring of Redis
2. **Core Last**: `cleanup-container.sh` removes the Redis cluster being monitored

### Start/Stop Order
- **Start**: Core containers first, then supporting services
- **Stop**: Supporting services first, then core containers

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
- Redis Master availability and role
- Redis Replica count and replication lag
- Sentinel cluster quorum and master discovery
- Session cleanup job execution history
- Persistent volume availability and usage

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
./scripts/containerManagement/deploy-supporting-services.sh

# Check everything is working
./scripts/containerManagement/get-container-status.sh
```

### Production Deployment
```bash
# Ensure environment is configured
cp .env.example .env
# Edit .env with production passwords

# Deploy with validation
./scripts/containerManagement/deploy-container.sh
./scripts/containerManagement/deploy-supporting-services.sh

# Verify deployment
./scripts/containerManagement/get-container-status.sh
./scripts/containerManagement/get-supporting-services-status.sh
```

### Troubleshooting
```bash
# Check status of all components
./scripts/containerManagement/get-container-status.sh
./scripts/containerManagement/get-supporting-services-status.sh

# Common troubleshooting
kubectl get pods -n session-database
kubectl describe pods -n session-database
kubectl logs -n session-database -l app.kubernetes.io/name=session-database
```

This documentation ensures consistent usage patterns across the distributed system and provides a clear migration path to the SystemManagement project.
