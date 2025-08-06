# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an enterprise-grade Redis-based session storage service for microservices with high availability, comprehensive security, and production-ready monitoring. The system has been modernized from a basic Redis setup to a fully-featured, production-ready deployment.

## Architecture

### Core Components
- **High Availability Redis**: Redis Sentinel with master-replica setup for automatic failover
- **Session Management**: TTL-based sessions with automated cleanup via CronJob
- **Token Systems**: Refresh tokens and deletion tokens with separate TTL management
- **Security Hardening**: Network policies, TLS encryption, ACL authentication, Pod Security Standards
- **Infrastructure as Code**: Helm charts with GitOps workflow via ArgoCD
- **Comprehensive Monitoring**: Prometheus, Grafana, Alertmanager with 20+ alerting rules

### Deployment Modes
1. **Standalone**: Single Redis instance (development only)
2. **Sentinel**: Redis Sentinel HA setup (recommended for production)
3. **Cluster**: Redis Cluster mode (future enhancement)

## Key Components

### Deployment Architecture
This system supports both **Standalone** and **High Availability (HA)** deployments:

#### Standalone Mode (`k8s/redis/standalone/`)
- **Single Redis Instance**: Development-focused deployment with HPA for scaling
- **Persistent Storage**: PVC-backed data persistence
- **Simple Configuration**: Suitable for development and testing environments

#### High Availability Setup (`k8s/redis/ha/`)
- **Redis Master**: Primary instance with persistent storage and full write capability (`k8s/redis/ha/master/`)
- **Redis Replicas**: 2+ read replicas for load distribution and failover candidates (`k8s/redis/ha/replica/`)
- **Redis Sentinel**: 3 instances monitoring master health and coordinating failover (`k8s/redis/ha/sentinel/`)
- **Automatic Failover**: Sub-minute failover with zero data loss
- **Production Ready**: Complete HA setup with proper health checks and networking

### Security Implementation
- **Network Policies**: Strict pod-to-pod communication rules
- **Pod Security Standards**: Enforced "restricted" profile with non-root containers
- **TLS Encryption**: Optional TLS for Redis connections with automatic certificate generation
- **ACL Authentication**: Role-based Redis access control with dedicated users for different functions
- **Service Accounts**: Minimal RBAC permissions for each component

### Monitoring & Alerting (Organized by Application)
- **Prometheus**: Metrics collection with 15s scrape interval and 30-day retention (`k8s/prometheus/`)
- **Grafana**: Comprehensive dashboards for Redis cluster health and session metrics (`k8s/grafana/`)
- **Alertmanager**: 15+ critical and warning alerts for proactive incident response (`k8s/alertmanager/`)
- **Redis Exporter**: Detailed Redis metrics including memory, connections, and performance (`k8s/prometheus/redis-exporter/`)

### Automated Operations
- **Session Cleanup CronJob**: Runs every 2-5 minutes to clean expired sessions/tokens (`k8s/redis/shared/`)
- **Health Checks**: Comprehensive liveness, readiness, and startup probes
- **Autoscaling**: HPA based on CPU (70%) and memory (80%) utilization (`k8s/redis/autoscaling/`)
- **Backup Automation**: Configurable backup strategies with persistent volume snapshots

## Common Commands

### Quality Assurance & Validation
```bash
# Run pre-commit hooks (includes security scanning, linting, kube-score validation)
pre-commit run --all-files

# Run individual tools
yamllint k8s/
shellcheck scripts/**/*.sh
kube-score score k8s/**/*.yaml --exclude-templates

# Security scanning
gitleaks detect --source .
trivy fs --severity HIGH,CRITICAL .
```

### Modern Deployment (Recommended)

#### Helm Deployment
```bash
# Development deployment
helm install session-database ./helm/session-database \
  --namespace session-database --create-namespace

# Production deployment with HA
helm install session-database ./helm/session-database \
  --namespace session-database --create-namespace \
  --values ./helm/session-database/values-production.yaml
```

#### GitOps with ArgoCD
```bash
# Deploy ArgoCD application
kubectl apply -f k8s/argocd/application.yaml

# Multi-environment setup
kubectl apply -f k8s/argocd/applicationset.yaml
```

### Script-Based Deployment (Development/Legacy)
```bash
# Deploy Redis HA cluster
./scripts/containerManagement/deploy-container.sh

# Deploy monitoring, alerting, and security
./scripts/containerManagement/deploy-monitoring.sh

# Check deployment status
./scripts/containerManagement/get-container-status.sh
```

**Note**: These scripts follow consistent patterns across the distributed system. See [CONTAINERMAGAGEMENT.md](CONTAINERMAGAGEMENT.md) for detailed script documentation and SystemManagement project compatibility.

### Database Operations
```bash
# Connect to Redis (standalone mode)
kubectl exec -it deployment/session-database -n session-database -- redis-cli -a $REDIS_PASSWORD

# Connect to Redis HA master
kubectl exec -it deployment/redis-master -n session-database -- redis-cli -a $REDIS_PASSWORD

# Check Sentinel status (HA mode)
kubectl exec -it deployment/redis-sentinel -n session-database -- redis-cli -p 26379 -a $SENTINEL_PASSWORD sentinel masters

# Monitor session cleanup
kubectl logs -n session-database -l component=maintenance -f

# Database management scripts
./scripts/dbManagement/redis-connect.sh           # Interactive Redis connection
./scripts/dbManagement/backup-sessions.sh         # Backup session data
./scripts/dbManagement/monitor-sessions.sh        # Monitor session metrics
./scripts/jobHelpers/session-health-check.sh      # Comprehensive health check
```

### Monitoring Access
```bash
# Access monitoring tools (development)
kubectl port-forward svc/prometheus-service -n session-database 9090:9090
kubectl port-forward svc/grafana-service -n session-database 3000:3000
kubectl port-forward svc/alertmanager-service -n session-database 9093:9093

# Production access via ingress
# https://prometheus.session-db.example.com
# https://grafana.session-db.example.com
```

## Data Model & Performance

### Redis Data Structures
- **Sessions**: `session:{session_id}` (hash with TTL) - stores complete session data
- **User Sessions**: `user_sessions:{user_id}` (set) - tracks active sessions per user
- **Refresh Tokens**: `refresh_token:{token}` (hash with TTL) - JWT refresh tokens
- **Deletion Tokens**: `deletion_token:{token}` (hash with TTL) - secure deletion tokens
- **Cleanup Tracking**: Sorted sets with expiration timestamps for efficient cleanup

### Performance Optimizations
- **Memory Management**: LRU eviction policy with configurable memory limits
- **Persistence**: AOF + RDB with optimized settings for session workloads
- **Connection Pooling**: TCP keepalive and connection limit configurations
- **Data Structures**: Optimized ziplist settings for session data patterns

## Configuration Management

### Environment-Specific Configuration
- **Development**: `values.yaml` - Single instance, minimal resources
- **Staging**: `values-staging.yaml` - HA setup with moderate resources
- **Production**: `values-production.yaml` - Full HA, enterprise resources, TLS

### Secret Management
```bash
# Development (basic)
kubectl create secret generic session-database-secret \
  --from-literal=redis-password=your-password

# Production (external secrets)
# Use Vault, AWS Secrets Manager, or similar
```

### Key Configuration Options
```yaml
# High Availability
ha:
  sentinel:
    enabled: true
    replicas: 3
  master:
    persistence:
      enabled: true
      size: "50Gi"
  replica:
    replicas: 3

# Security
security:
  networkPolicies:
    enabled: true
  podSecurityStandards:
    enforce: "restricted"
  tls:
    enabled: true  # Production only

# Monitoring
monitoring:
  prometheus:
    retention: "720h"  # 30 days
  alertmanager:
    enabled: true
```

## Development Workflow

### Modern Development Process
1. **Local Development**: Use Helm with development values
2. **Feature Branches**: ArgoCD ApplicationSet automatically deploys feature branches
3. **Testing**: Automated integration tests with cleanup job validation
4. **Security**: Enhanced pre-commit hooks with vulnerability scanning
5. **Deployment**: GitOps workflow with automated rollbacks

### Quality Assurance
- **Pre-commit Hooks**: Security scanning (gitleaks, trivy, detect-secrets), Kubernetes validation (kube-score), YAML/shell linting
- **Kubernetes Validation**: Complete kube-score validation with cross-directory resource validation
- **Security Scanning**: Multiple layers including container vulnerability scanning and secret detection
- **Code Quality**: Shell script validation (shellcheck), YAML validation (yamllint), Helm chart validation
- **CI/CD Pipeline**: Automated testing, security scanning, and deployment validation
- **Monitoring**: Comprehensive alerting for early problem detection

### Testing Strategy
```bash
# Run integration tests
kubectl apply -f tests/integration/

# Load testing
kubectl apply -f tests/load/

# Chaos engineering
kubectl apply -f tests/chaos/
```

## Security Features

### Multi-Layer Security
- **Network Security**: Network policies restricting pod-to-pod communication
- **Runtime Security**: Pod Security Standards with non-root containers and minimal privileges
- **Data Security**: TLS encryption, ACL-based access control, secret management
- **Audit Security**: Comprehensive logging and monitoring of access patterns

### Compliance Features
- **RBAC**: Role-based access control for all components
- **Audit Logging**: Complete audit trail of administrative actions
- **Secret Rotation**: Support for automated secret rotation
- **Vulnerability Scanning**: Automated container and infrastructure scanning

## Troubleshooting

### Common Issues
1. **Master Failover**: Check Sentinel logs and quorum status
2. **Network Connectivity**: Verify network policies and DNS resolution
3. **Resource Pressure**: Monitor HPA scaling and resource utilization
4. **Security Blocks**: Check Pod Security Standards and service account permissions

### Debug Commands
```bash
# Check cluster health
kubectl get pods,svc,pvc -n session-database

# Check Sentinel status
kubectl exec -it redis-sentinel-xxx -- redis-cli -p 26379 sentinel masters

# View comprehensive logs
kubectl logs -n session-database -l app.kubernetes.io/name=session-database --tail=100

# Check alerts
kubectl port-forward svc/alertmanager-service 9093:9093

# Script-based status checking
./scripts/containerManagement/get-container-status.sh           # Redis cluster health
./scripts/containerManagement/get-supporting-services-status.sh # Monitoring/security status
```

## Container Management Scripts

For development environments and consistent deployment patterns across the distributed system, use the containerManagement scripts:

### Script Categories
- **Core Scripts**: Manage Redis HA cluster (Master, Replicas, Sentinel)
- **Supporting Scripts**: Manage monitoring, alerting, and security components

### Common Operations
```bash
# Full deployment workflow
./scripts/containerManagement/deploy-container.sh
./scripts/containerManagement/deploy-monitoring.sh

# Maintenance operations
./scripts/containerManagement/stop-container.sh    # Maintenance mode
./scripts/containerManagement/start-container.sh   # Resume operations

# Status monitoring
./scripts/containerManagement/get-container-status.sh
./scripts/containerManagement/get-supporting-services-status.sh

# Clean removal (proper order)
./scripts/containerManagement/cleanup-supporting-services.sh
./scripts/containerManagement/cleanup-container.sh
```

See [CONTAINERMAGAGEMENT.md](CONTAINERMAGAGEMENT.md) for comprehensive script documentation, style patterns, and SystemManagement project compatibility.

This modernized deployment provides enterprise-grade session storage suitable for production microservices architectures with comprehensive monitoring, security, and operational capabilities.
