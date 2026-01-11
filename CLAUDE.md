# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

Enterprise-grade Redis-based OAuth2 authentication service for microservices
with high availability (Sentinel), multi-database architecture, comprehensive
monitoring, and GitOps deployment via ArgoCD.

## Build & Validation

```bash
# Setup pre-commit hooks (first time)
pre-commit install && pre-commit install --hook-type commit-msg

# Run all validations
pre-commit run --all-files

# Individual tools
yamllint k8s/
shellcheck scripts/**/*.sh
helm lint ./helm/redis-database
helm template ./helm/redis-database  # Validate Helm templates
kube-score score k8s/**/*.yaml --exclude-templates

# Security scanning
gitleaks detect --source .
trivy fs --severity HIGH,CRITICAL .
```

## Deployment

### Helm (Recommended)

```bash
# Development
helm install redis-database ./helm/redis-database \
  --namespace redis-database --create-namespace

# Production with HA
helm install redis-database ./helm/redis-database \
  --namespace redis-database --create-namespace \
  --values ./helm/redis-database/values-production.yaml

# GitOps with ArgoCD
kubectl apply -f k8s/argocd/application.yaml
```

### Script-based (Development)

```bash
./scripts/containerManagement/deploy-container.sh      # Deploy Redis HA
./scripts/containerManagement/deploy-monitoring.sh     # Deploy monitoring
./scripts/containerManagement/get-container-status.sh  # Check status
./scripts/containerManagement/stop-container.sh        # Stop for maintenance
./scripts/containerManagement/start-container.sh       # Resume
./scripts/containerManagement/cleanup-container.sh     # Remove Redis
./scripts/containerManagement/cleanup-monitoring.sh    # Remove monitoring
```

### External Access (NodePort)

```bash
# Access via hostname (after deploy-container.sh configures /etc/hosts)
redis-cli -h redis-database.local -p $REDIS_NODEPORT -a $REDIS_PASSWORD
```

NodePort defaults (configurable in `.env`): `REDIS_NODEPORT=30379`,
`SENTINEL_NODEPORT=30380`, `REPLICA_NODEPORT=30381`

## Database Operations

```bash
# Connect to Auth DB (0)
kubectl exec -it deployment/redis-database -n redis-database -- \
  redis-cli -a $REDIS_PASSWORD -n 0

# Connect to Cache DB (1)
kubectl exec -it deployment/redis-database -n redis-database -- \
  redis-cli -a $REDIS_PASSWORD -n 1

# HA mode - connect to master
kubectl exec -it deployment/redis-master -n redis-database -- \
  redis-cli -a $REDIS_PASSWORD -n 0

# Check Sentinel status
kubectl exec -it deployment/redis-sentinel -n redis-database -- \
  redis-cli -p 26379 -a $SENTINEL_PASSWORD sentinel masters

# Helper scripts
./scripts/dbManagement/redis-connect.sh [0|1]  # Interactive connection
./scripts/dbManagement/auth-connect.sh         # Auth DB with utilities
./scripts/dbManagement/cache-connect.sh        # Cache DB with utilities
./scripts/dbManagement/backup-auth.sh [all|auth|cache]
./scripts/dbManagement/show-auth-info.sh       # Auth service info
./scripts/jobHelpers/session-health-check.sh   # Health check
```

## Monitoring

```bash
# Port-forward for local access
kubectl port-forward svc/prometheus-service -n redis-database 9090:9090
kubectl port-forward svc/grafana-service -n redis-database 3000:3000
kubectl port-forward svc/alertmanager-service -n redis-database 9093:9093
```

## Architecture

### Deployment Modes

1. **Standalone**: Single Redis instance (development only)
2. **Sentinel**: Redis Sentinel HA with master-replica (production)
3. **Cluster**: Redis Cluster mode (future)

### Core Components

- **Redis Sentinel HA**: Master + 2+ replicas + 3 Sentinel instances
- **Multi-Database**: DB 0 (OAuth2 auth), DB 1 (service cache)
- **Monitoring**: Prometheus, Grafana, Alertmanager, Redis Exporter
- **Security**: Network policies, TLS, ACL authentication, Pod Security Standards
- **Automated Ops**: Token cleanup CronJob (5 min), cache cleanup (10 min), HPA

### Data Model

**Auth Service Database (DB 0)**:

- `auth:client:{client_id}` - OAuth2 client registrations (hash)
- `auth:code:{code}` - Authorization codes (hash, 10 min TTL)
- `auth:access_token:{token}` - Access tokens (hash, 15 min TTL)
- `auth:refresh_token:{token}` - Refresh tokens (hash, 7 day TTL)
- `auth:session:{session_id}` - User sessions (hash, 1 hour TTL)
- `auth:blacklist:{token}` - Revoked tokens (string with TTL)
- `auth:rate_limit:{key}` - Rate limiting counters (int with TTL)
- `auth_stats`, `auth_config` - Metrics and configuration

**Service Cache Database (DB 1)**:

- `cache:resource:{name}` - Cached resources (hash, 24h default TTL)
- `cache_stats`, `cache_config` - Cache metrics and settings

## Commit Convention

Uses [Conventional Commits](https://www.conventionalcommits.org/) - enforced by
pre-commit hooks:

```bash
feat: add new feature           # Minor version bump
fix: resolve bug                # Patch version bump
docs: update documentation      # Patch version bump
feat!: breaking change          # Major version bump
```

## Troubleshooting

### Debug Commands

```bash
# Check cluster health
kubectl get pods,svc,pvc -n redis-database

# View logs
kubectl logs -n redis-database -l app.kubernetes.io/name=redis-database --tail=100

# Check Sentinel
kubectl exec -it redis-sentinel-xxx -- redis-cli -p 26379 sentinel masters

# Monitor cleanup jobs
kubectl logs -n redis-database -l component=maintenance -f

# Script-based status
./scripts/containerManagement/get-container-status.sh
```

### Common Issues

1. **Master Failover**: Check Sentinel logs and quorum status
2. **Permission denied on config/data**: Ensure fsGroup (999) or use PVC
3. **AOF directory failed**: Redis 8.0+ needs writable data directory
4. **Health probe failures**: Verify REDIS_PASSWORD env var substitution
5. **Init Job timeout**: Ensure Redis is ready before Lua scripts run
