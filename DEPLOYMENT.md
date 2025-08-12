# Session Database & Service Cache Deployment Guide

This guide covers the deployment of the Redis-based session database and service cache system with high availability, comprehensive monitoring, and security hardening.

## Architecture Overview

The modernized session database and cache system now includes:

- **Multi-Database Architecture**: Isolated databases for sessions (DB 0) and service cache (DB 1)
- **High Availability**: Redis Sentinel with master-replica setup
- **Security**: Network policies, TLS encryption, ACL authentication, Pod Security Standards
- **Monitoring**: Prometheus, Grafana, Alertmanager with comprehensive alerting rules
- **Automation**: Automated session and cache cleanup via CronJobs with intelligent eviction
- **Infrastructure as Code**: Helm charts with GitOps workflow via ArgoCD
- **Quality Assurance**: Enhanced pre-commit hooks with security scanning

## Quick Start

### Prerequisites

- Kubernetes cluster (1.25+)
- kubectl configured
- Helm 3.x installed
- ArgoCD installed (for GitOps)
- cert-manager (for TLS certificates in production)

### Environment Variables

Create an `.env` file with the following variables:

```bash
# Redis Configuration
REDIS_HOST=session-database-service.session-database.svc.cluster.local
REDIS_PORT=6379
REDIS_PASSWORD=your-secure-redis-password-here
REDIS_DB=0

# Redis Sentinel Configuration (for HA mode)
SENTINEL_PASSWORD=your-secure-sentinel-password-here

# Redis ACL User Passwords (for role-based access control)
# APP_PASSWORD: Used by applications for session CRUD operations
APP_PASSWORD=your-app-password-here

# MONITOR_PASSWORD: Used by Prometheus/monitoring tools (read-only access)
MONITOR_PASSWORD=your-monitor-password-here

# CLEANUP_PASSWORD: Used by cleanup CronJob for expired session removal
CLEANUP_PASSWORD=your-cleanup-password-here

# BACKUP_PASSWORD: Used by backup jobs (read-only access for backups)
BACKUP_PASSWORD=your-backup-password-here

# CACHE_PASSWORD: Used by cache operations for service cache database (DB 1)
CACHE_PASSWORD=your-cache-password-here

# Session Configuration
SESSION_TTL_SECONDS=3600
REFRESH_TOKEN_TTL_SECONDS=604800
MAX_SESSIONS_PER_USER=5
MAX_REFRESH_TOKENS_PER_USER=3
CLEANUP_INTERVAL_SECONDS=300

# Service Cache Configuration
CACHE_DB=1
CACHE_DEFAULT_TTL_SECONDS=86400
CACHE_CLEANUP_INTERVAL_SECONDS=600
CACHE_CLEANUP_BATCH_SIZE=200
CACHE_MAX_ENTRIES_PER_SERVICE=10000

# Kubernetes Configuration
NAMESPACE=session-database
POD_LABEL=app=session-database

# Logging
LOG_LEVEL=INFO
```

**Note**: Copy `.env.example` to `.env` and update with your secure passwords:
```bash
cp .env.example .env
# Edit .env with your secure passwords
```

## Deployment Options

### Option 1: Helm Deployment (Recommended)

#### Development Deployment

```bash
# Install with default values
helm install session-database ./helm/session-database \
  --namespace session-database \
  --create-namespace \
  --set redis.auth.password=your-redis-password \
  --set redis.auth.sentinel.password=your-sentinel-password
```

#### Production Deployment

```bash
# Install with production values
helm install session-database ./helm/session-database \
  --namespace session-database \
  --create-namespace \
  --values ./helm/session-database/values-production.yaml \
  --set redis.auth.password=your-redis-password \
  --set redis.auth.sentinel.password=your-sentinel-password
```

### Option 2: GitOps with ArgoCD (Recommended for Production)

1. **Install ArgoCD Application**:
```bash
kubectl apply -f k8s/argocd/application.yaml
```

2. **For Multi-Environment Setup**:
```bash
kubectl apply -f k8s/argocd/applicationset.yaml
```

3. **Access ArgoCD UI**:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Option 3: Script-based Deployment (Development/Legacy)

For development environments and legacy compatibility using containerManagement scripts:

#### Core Redis Deployment
```bash
# Deploy Redis HA cluster (Master, Replicas, Sentinel)
./scripts/containerManagement/deploy-container.sh

# Check Redis cluster status
./scripts/containerManagement/get-container-status.sh
```

#### Supporting Services Deployment
```bash
# Deploy monitoring, alerting, and security components
./scripts/containerManagement/deploy-supporting-services.sh

# Check supporting services status
./scripts/containerManagement/get-supporting-services-status.sh
```

#### Complete Script-based Workflow
```bash
# Full deployment
./scripts/containerManagement/deploy-container.sh
./scripts/containerManagement/deploy-supporting-services.sh

# Verify deployment
./scripts/containerManagement/get-container-status.sh
./scripts/containerManagement/get-supporting-services-status.sh

# Maintenance operations
./scripts/containerManagement/stop-container.sh      # Stop for maintenance
./scripts/containerManagement/start-container.sh     # Resume operations

# Clean removal (supporting services first, then core)
./scripts/containerManagement/cleanup-supporting-services.sh
./scripts/containerManagement/cleanup-container.sh
```

**Note**: These scripts follow consistent patterns across the distributed system and are designed for eventual migration to a SystemManagement project. See [CONTAINERMAGAGEMENT.md](CONTAINERMAGAGEMENT.md) for detailed documentation.

### Option 4: Manual Kubernetes Manifests

For advanced customization or when other deployment methods are not available:

```bash
# Apply all manifests in order by application

# 1. Shared resources first
kubectl apply -f k8s/shared/podsecurity.yaml
kubectl apply -f k8s/templates/secret-template.yaml      # After substituting environment variables
kubectl apply -f k8s/templates/configmap-template.yaml  # After substituting environment variables
kubectl apply -f k8s/shared/networkpolicy.yaml

# 2. Redis components (choose standalone OR ha deployment)

# Option A: Standalone Redis deployment
kubectl apply -f k8s/redis/standalone/

# Option B: High Availability Redis deployment
kubectl apply -f k8s/redis/ha/master/
kubectl apply -f k8s/redis/ha/replica/
kubectl apply -f k8s/redis/ha/sentinel/
kubectl apply -f k8s/redis/shared/          # Session cleanup jobs
kubectl apply -f k8s/redis/autoscaling/     # HPA

# 3. Monitoring stack
kubectl apply -f k8s/prometheus/
kubectl apply -f k8s/grafana/
kubectl apply -f k8s/alertmanager/

# 4. Additional shared resources
kubectl apply -f k8s/shared/ingress.yaml
kubectl apply -f k8s/shared/tls-certificates.yaml
```

## Configuration

### High Availability Settings

The system automatically configures:
- **Redis Sentinel**: 3 instances for automatic failover
- **Redis Master**: 1 instance with persistent storage
- **Redis Replicas**: 2 instances for read scaling
- **Cleanup Jobs**: Automated session cleanup every 2-5 minutes

### Security Configuration

#### Network Policies
- Restricts pod-to-pod communication
- Allows access only from authorized applications
- Isolates monitoring traffic

#### Pod Security Standards
- Enforces "restricted" security profile
- Non-root containers with minimal privileges
- Read-only root filesystems where possible

#### Authentication & Authorization
- Redis ACL with role-based access
- Dedicated service accounts with minimal RBAC
- TLS encryption for Redis connections (production)

### Monitoring & Alerting

#### Prometheus Metrics
- Redis instance health and performance
- Session statistics and cleanup metrics
- Kubernetes resource utilization
- Custom business metrics

#### Grafana Dashboards
- Redis cluster overview
- Session management metrics
- Resource utilization
- Alert status and history

#### Alerting Rules
- **Critical**: Redis down, memory exhaustion, cleanup failures
- **Warning**: High connection count, low hit rate, resource pressure
- **Info**: Session statistics, cleanup runs

## Operations

### Monitoring Access

```bash
# Port forward to access monitoring tools
kubectl port-forward svc/prometheus-service -n session-database 9090:9090
kubectl port-forward svc/grafana-service -n session-database 3000:3000
kubectl port-forward svc/alertmanager-service -n session-database 9093:9093
```

Default credentials:
- **Grafana**: admin/admin (change immediately)
- **Prometheus**: No authentication (use ingress with auth in production)

### Health Checks

```bash
# Check overall system health
./scripts/jobHelpers/session-health-check.sh

# Check individual components
kubectl get pods -n session-database
kubectl get services -n session-database
kubectl get cronjobs -n session-database
```

### Scaling

#### Manual Scaling
```bash
# Scale Redis replicas
kubectl scale deployment redis-replica -n session-database --replicas=5

# Scale Sentinel instances
kubectl scale deployment redis-sentinel -n session-database --replicas=5
```

#### Automatic Scaling
The system includes HorizontalPodAutoscaler for automatic scaling based on:
- CPU utilization (70% threshold)
- Memory utilization (80% threshold)

### Backup & Recovery

#### Manual Backup
```bash
# Create Redis backup
kubectl exec -n session-database redis-master-xxx -- redis-cli -a $REDIS_PASSWORD BGSAVE

# Export backup
kubectl cp session-database/redis-master-xxx:/data/dump.rdb ./backup-$(date +%Y%m%d).rdb
```

#### Automated Backup (Recommended)
Configure external backup solutions like:
- AWS EBS snapshots for persistent volumes
- Velero for full cluster backups
- Custom backup CronJobs with S3 storage

### Disaster Recovery

#### Master Failover
Redis Sentinel automatically handles master failover:
1. Detects master failure
2. Promotes a replica to master
3. Reconfigures other replicas
4. Updates application endpoints

#### Full Cluster Recovery
```bash
# Restore from backup
kubectl cp ./backup-20240101.rdb session-database/redis-master-xxx:/data/dump.rdb
kubectl delete pod redis-master-xxx -n session-database  # Triggers restart
```

## Security Best Practices

### Production Checklist

- [ ] Use external secret management (Vault, AWS Secrets Manager)
- [ ] Enable TLS encryption for all Redis connections
- [ ] Configure proper network policies for your application
- [ ] Set up proper RBAC for ArgoCD access
- [ ] Enable audit logging
- [ ] Regular security scanning with updated pre-commit hooks
- [ ] Monitor security alerts and update dependencies

### Secret Management

For production, replace direct password configuration with external secret management:

```yaml
# Example with External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: session-database-secrets
spec:
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: session-database-secret
  data:
  - secretKey: redis-password
    remoteRef:
      key: session-database
      property: redis-password
```

## Troubleshooting

### Common Issues

1. **Pods Not Starting**
   - Check resource quotas and limits
   - Verify PersistentVolume availability
   - Check security context restrictions

2. **Redis Connection Issues**
   - Verify passwords in secrets
   - Check network policies
   - Validate service endpoints

3. **Sentinel Failover Problems**
   - Ensure odd number of Sentinel instances
   - Check inter-pod communication
   - Verify Redis instance configuration

4. **Monitoring Not Working**
   - Check ServiceMonitor configuration
   - Verify Prometheus scrape targets
   - Validate RBAC permissions

### Debug Commands

```bash
# Check Redis master status
kubectl exec -n session-database redis-master-xxx -- redis-cli -a $REDIS_PASSWORD info replication

# Check Sentinel status
kubectl exec -n session-database redis-sentinel-xxx -- redis-cli -p 26379 -a $SENTINEL_PASSWORD sentinel masters

# View cleanup job logs
kubectl logs -n session-database -l component=maintenance

# Check network connectivity
kubectl exec -n session-database redis-master-xxx -- nslookup redis-replica-service
```

## Performance Tuning

### Redis Configuration

Key performance settings in production:
```yaml
redis:
  config:
    maxmemory: "4gb"
    maxmemoryPolicy: "allkeys-lru"
    save: "900 1 300 10 60 10000"
    tcpKeepalive: 300
```

### Kubernetes Resources

Adjust based on your workload:
```yaml
resources:
  requests:
    memory: "4Gi"
    cpu: "2000m"
  limits:
    memory: "8Gi"
    cpu: "4000m"
```

### Storage Performance

Use high-performance storage classes:
- AWS: gp3 or io2
- GCP: pd-ssd
- Azure: Premium_LRS

## Maintenance

### Regular Tasks

1. **Weekly**:
   - Review monitoring alerts
   - Check resource utilization
   - Validate backup integrity

2. **Monthly**:
   - Update security patches
   - Review access logs
   - Performance optimization review

3. **Quarterly**:
   - Disaster recovery testing
   - Security audit
   - Capacity planning review

### Updates

#### Application Updates
```bash
# Update via Helm
helm upgrade session-database ./helm/session-database \
  --namespace session-database \
  --values ./helm/session-database/values-production.yaml

# Update via ArgoCD (GitOps)
# Push changes to git repository - ArgoCD will automatically sync
```

#### Security Updates
```bash
# Update base images
docker build --no-cache -t session-database:new-version .

# Run security scans
pre-commit run --all-files
```

This deployment provides enterprise-grade Redis session storage with comprehensive monitoring, security, and operational capabilities suitable for production workloads.
