# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

This is an enterprise-grade Redis-based OAuth2 authentication service for
microservices with high availability, comprehensive security, and
production-ready monitoring. The system has been modernized from a basic Redis
setup to a fully-featured, production-ready OAuth2 service deployment.

## Architecture

### Core Components

- **High Availability Redis**: Redis Sentinel with master-replica setup for
  automatic failover
- **Multi-Database Architecture**: Isolated databases for OAuth2 auth service
  (DB 0) and service cache (DB 1)
- **OAuth2 Authentication**: Full OAuth2 server with authorization codes,
  access/refresh tokens
- **Service Cache System**: Dedicated caching layer with LRU and TTL-based
  cleanup strategies
- **Token Management**: Complete token lifecycle with automatic cleanup and
  blacklisting
- **Security Hardening**: Network policies, TLS encryption, ACL authentication,
  Pod Security Standards, rate limiting
- **Infrastructure as Code**: Helm charts with GitOps workflow via ArgoCD
- **Comprehensive Monitoring**: Prometheus, Grafana, Alertmanager with 20+
  alerting rules

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

- **Redis Master**: Primary instance with persistent storage and full write
  capability (`k8s/redis/ha/master/`)
- **Redis Replicas**: 2+ read replicas for load distribution and failover
  candidates (`k8s/redis/ha/replica/`)
- **Redis Sentinel**: 3 instances monitoring master health and coordinating
  failover (`k8s/redis/ha/sentinel/`)
- **Automatic Failover**: Sub-minute failover with zero data loss
- **Production Ready**: Complete HA setup with proper health checks and networking

### Security Implementation

- **Network Policies**: Strict pod-to-pod communication rules
- **Pod Security Standards**: Enforced "restricted" profile with non-root containers
- **TLS Encryption**: Optional TLS for Redis connections with automatic
  certificate generation
- **ACL Authentication**: Role-based Redis access control with dedicated users
  for different functions
- **Service Accounts**: Minimal RBAC permissions for each component

### Monitoring & Alerting (Organized by Application)

- **Prometheus**: Metrics collection with 15s scrape interval and 30-day
  retention (`k8s/prometheus/`)
- **Grafana**: Comprehensive dashboards for Redis cluster health and session
  metrics (`k8s/grafana/`)
- **Alertmanager**: 15+ critical and warning alerts for proactive incident
  response (`k8s/alertmanager/`)
- **Redis Exporter**: Detailed Redis metrics including memory, connections, and
  performance (`k8s/prometheus/redis-exporter/`)

### Database Initialization System

The deployment uses a **two-phase startup process** for robust database initialization:

1. **Phase 1 - Redis Startup**: Redis server starts with generated
   configuration and becomes ready for connections
2. **Phase 2 - Database Initialization**: Separate Kubernetes Job
   (`k8s/redis/standalone/init-job.yaml`) runs Lua scripts to initialize:
   - **Auth Service Database (DB 0)**:
     - OAuth2 client registrations and configurations
     - Authorization code structures and TTL management
     - Access token and refresh token tracking
     - User authentication session management
     - Token blacklisting and revocation systems
     - Rate limiting structures and counters
     - Auth service statistics and configuration
   - **Service Cache Database (DB 1)**:
     - Cache key structures for different service types
     - Cache cleanup and eviction tracking
     - Performance metrics and hit ratio monitoring
     - Service-specific cache configuration

This separation ensures Redis is fully operational before complex
initialization, improving reliability and startup time.

### Automated Operations

- **Token Cleanup CronJob**: Runs every 5 minutes to clean expired
  OAuth2 tokens and authorization codes (`k8s/redis/shared/`)
- **Cache Cleanup CronJob**: Runs every 10 minutes to clean expired cache
  entries with LRU eviction
- **Health Checks**: Comprehensive liveness, readiness, and startup probes
- **Autoscaling**: HPA based on CPU (70%) and memory (80%) utilization
  (`k8s/redis/autoscaling/`)
- **Multi-Database Backup**: Configurable backup strategies supporting both
  auth service and cache databases
- **Performance Monitoring**: Cache hit ratio tracking and performance metrics collection

## Common Commands

### Quality Assurance & Validation

```bash
# Setup development environment with conventional commits
pre-commit install
pre-commit install --hook-type commit-msg
git config commit.template .gitmessage

# Run pre-commit hooks (includes security scanning, linting, kube-score
# validation, conventional commits)
pre-commit run --all-files

# Run individual tools
yamllint k8s/
shellcheck scripts/**/*.sh
kube-score score k8s/**/*.yaml --exclude-templates

# Security scanning
gitleaks detect --source .
trivy fs --severity HIGH,CRITICAL .

# Test conventional commit format (enforced by pre-commit)
git commit -m "feat: add new Redis feature"
git commit -m "fix(auth): resolve authentication timeout"
git commit -m "docs: update deployment guide"
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

**Note**: These scripts follow consistent patterns across the distributed
system. See [CONTAINERMAGAGEMENT.md](docs/CONTAINERMAGAGEMENT.md) for detailed script
documentation and SystemManagement project compatibility.

### Database Operations

```bash
# Connect to Redis databases
# Connect to auth service database
kubectl exec -it deployment/session-database -n session-database -- \
  redis-cli -a $REDIS_PASSWORD -n 0  # Auth DB
# Connect to cache database
kubectl exec -it deployment/session-database -n session-database -- \
  redis-cli -a $REDIS_PASSWORD -n 1  # Cache DB

# Connect to Redis HA master
# Connect to HA master auth service database
kubectl exec -it deployment/redis-master -n session-database -- \
  redis-cli -a $REDIS_PASSWORD -n 0      # Auth DB
# Connect to HA master cache database
kubectl exec -it deployment/redis-master -n session-database -- \
  redis-cli -a $REDIS_PASSWORD -n 1      # Cache DB

# Check Sentinel status (HA mode)
# Check Sentinel status (HA mode)
kubectl exec -it deployment/redis-sentinel -n session-database -- \
  redis-cli -p 26379 -a $SENTINEL_PASSWORD sentinel masters

# Monitor cleanup operations
kubectl logs -n session-database -l component=maintenance -f

# Database management scripts
# Interactive Redis connection (DB 0=auth, DB 1=cache)
./scripts/dbManagement/redis-connect.sh [0|1]
# Auth-specific Redis connection with utilities
./scripts/dbManagement/auth-connect.sh
# Cache-specific Redis connection with utilities
./scripts/dbManagement/cache-connect.sh
./scripts/dbManagement/backup-auth.sh [all|auth|cache]  # Backup database(s)
./scripts/dbManagement/monitor-auth.sh             # Monitor OAuth2 auth metrics
./scripts/dbManagement/show-auth-info.sh           # Comprehensive auth service info
./scripts/jobHelpers/session-health-check.sh       # Comprehensive health check
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

### Multi-Database Architecture

The system uses **Redis logical databases** to provide complete data isolation:

#### Auth Service Database (DB 0)

- **OAuth2 Clients**: `auth:client:{client_id}` (hash) - OAuth2 client
  registrations with credentials and configuration
- **Authorization Codes**: `auth:code:{code}` (hash with TTL) - temporary
  OAuth2 authorization codes for token exchange
- **Access Tokens**: `auth:access_token:{token}` (hash with TTL) - access
  token metadata for validation and introspection
- **Refresh Tokens**: `auth:refresh_token:{token}` (hash with TTL) - refresh
  token metadata for token rotation
- **Auth Sessions**: `auth:session:{session_id}` (hash with TTL) - user
  authentication session storage
- **Token Blacklist**: `auth:blacklist:{token}` (string with TTL) -
  revoked/compromised token tracking
- **Rate Limiting**: `auth:rate_limit:{key}` (integer with TTL) - request
  rate limiting counters (IP/client/endpoint based)
- **Token Cleanup**: `auth_token_cleanup` (sorted set) - expiration
  timestamps for efficient cleanup
- **Auth Statistics**: `auth_stats` (hash) - OAuth2 metrics and counters
- **Auth Configuration**: `auth_config` (hash) - TTL settings, limits, and
  OAuth2 configuration

#### Service Cache Database (DB 1)

- **Resource Cache**: `cache:resource:*` (hash with TTL) - Currently used by
  recipe scraper service
  - Example: `cache:resource:popular_recipes` - Cached recipe data with 24h TTL
- **Cache Statistics**: `cache_stats` (hash) - Basic cache metrics and counters
- **Cache Configuration**: `cache_config` (hash) - TTL defaults and basic settings
- **Cache Cleanup Metrics**: `cache_cleanup_metrics` (hash) - Simple cleanup tracking

**Note**: The cache system is designed to be simple and relies on Redis TTL
for automatic expiration. Additional cache patterns can be added as needed
following the `cache:resource:*` format.

### Performance Optimizations

- **Database Isolation**: Complete separation prevents OAuth2 auth and cache
  operations from interfering
- **Memory Management**: Independent LRU eviction policies per database with
  configurable limits
- **Persistence**: AOF + RDB with optimized settings for both auth and cache workloads
- **Connection Pooling**: TCP keepalive and connection limit configurations
- **Data Structures**: Optimized ziplist settings for both auth and cache
  data patterns
- **Token Strategies**: Automatic TTL-based expiration with cleanup jobs
- **Monitoring Granularity**: Separate Redis exporters for auth and cache databases

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
# Storage Configuration (Recommended: PVC)
storage:
  # Primary option - PersistentVolumeClaim (recommended)
  type: "persistentVolumeClaim"
  size: "10Gi"
  storageClass: "standard"

  # Alternative - hostPath (development only)
  # type: "hostPath"
  # path: "/mnt/session-database/redis/data"

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

# OAuth2 Auth Service Configuration
authService:
  database: 0 # Auth database number
  tokenTTL:
    authorizationCode: 600 # 10 minutes
    accessToken: 900 # 15 minutes
    refreshToken: 604800 # 7 days
    sessionTimeout: 3600 # 1 hour
  rateLimiting:
    enabled: true
    defaultRequestsPerMinute: 100
    clientRequestsPerMinute: 1000
    ipRequestsPerMinute: 50
  cleanup:
    enabled: true
    schedule: "*/5 * * * *" # Every 5 minutes
    batchSize: 500

# Service Cache Configuration
serviceCache:
  database: 1 # Cache database number
  defaultTTL: 86400 # 24 hours default cache TTL
  cleanup:
    enabled: true
    schedule: "*/10 * * * *" # Every 10 minutes
    batchSize: 200
    # Simple TTL-based cleanup (Redis handles expiration automatically)
  config:
    maxEntriesPerService: 10000
    hitRatioThreshold: 0.8
    memoryThreshold: "512Mi"

# Security
security:
  networkPolicies:
    enabled: true
  podSecurityStandards:
    enforce: "restricted"
  tls:
    enabled: true # Production only

# Monitoring
monitoring:
  prometheus:
    retention: "720h" # 30 days
  alertmanager:
    enabled: true
  redisExporter:
    enabled: true # Monitors auth database
  redisCacheExporter:
    enabled: true # Monitors cache database
```

## Development Workflow

### Modern Development Process

1. **Local Development**: Use Helm with development values
2. **Feature Branches**: ArgoCD ApplicationSet automatically deploys feature branches
3. **Conventional Commits**: Enforced commit message format for automated releases
4. **Testing**: Automated integration tests with cleanup job validation
5. **Security**: Enhanced pre-commit hooks with vulnerability scanning
6. **Deployment**: GitOps workflow with automated rollbacks
7. **Releases**: Automated semantic versioning and GitHub releases

### Commit Guidelines

Follow [Conventional Commits](https://www.conventionalcommits.org/) for
consistent commits and automated releases:

```bash
# Commit types that trigger releases
feat: add new Redis Sentinel support        # → Minor version (1.1.0)
fix: resolve authentication timeout         # → Patch version (1.0.1)
perf: optimize Redis connection pooling     # → Patch version (1.0.1)
docs: update deployment documentation       # → Patch version (1.0.1)

# Breaking changes trigger major releases
feat!: migrate to Redis 7.0 ACL system    # → Major version (2.0.0)
```

### Automated Release Process

The release workflow triggers on pushes to `main` branch:

1. **Semantic Analysis**: Analyzes conventional commits since last release
2. **Version Calculation**: Determines next semantic version (major.minor.patch)
3. **Changelog Generation**: Auto-generates CHANGELOG.md from commit messages
4. **GitHub Release**: Creates release with categorized release notes
5. **Docker Images**: Builds and pushes multi-arch images to GHCR
6. **Helm Chart**: Packages and attaches chart to GitHub release

#### Release Artifacts

Each automated release produces:

- Git tag (e.g., `v1.2.3`)
- GitHub release with notes
- Docker images: `ghcr.io/recipe-web-app/session-database:latest` and `ghcr.io/recipe-web-app/session-database:v1.2.3`
- Helm chart package attached to release

### Quality Assurance

- **Pre-commit Hooks**: Security scanning (gitleaks, trivy, detect-secrets),
  Kubernetes validation (kube-score), YAML/shell linting, conventional commits
  validation
- **Kubernetes Validation**: Complete kube-score validation with
  cross-directory resource validation
- **Security Scanning**: Multiple layers including container vulnerability
  scanning and secret detection
- **Code Quality**: Shell script validation (shellcheck), YAML validation
  (yamllint), Helm chart validation
- **Commit Standards**: Conventional commits enforced with automated semantic release
- **CI/CD Pipeline**: Automated testing, security scanning, deployment
  validation, and release automation
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
- **Runtime Security**: Pod Security Standards with non-root containers and
  minimal privileges
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
5. **Redis Startup Failures**:
   - **Permission denied on config/data directories**: Ensure proper fsGroup
     (999) or use PVC instead of hostPath
   - **AOF directory creation failed**: Redis 8.0+ requires writable data
     directory for append-only files
   - **Read-only filesystem errors**: Check volume mounts and security context settings
6. **Pod Readiness Issues**:
   - **Health probe failures**: Verify Redis password environment variable
     substitution in probes
   - **Startup timeout**: Check if Redis process is actually starting (review
     logs for config errors)
7. **Init Job Problems**:
   - **Job timeout**: Ensure Redis is ready before Lua initialization starts
   - **Connection refused**: Verify service name and port configuration in init job

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

# Check monitoring services manually
kubectl get pods,svc -n session-database -l component=monitoring
```

## Container Management Scripts

For development environments and consistent deployment patterns across the
distributed system, use the containerManagement scripts:

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

# Clean removal (proper order)
./scripts/containerManagement/cleanup-monitoring.sh
./scripts/containerManagement/cleanup-container.sh
```

See [CONTAINERMAGAGEMENT.md](docs/CONTAINERMAGAGEMENT.md) for comprehensive script
documentation, style patterns, and SystemManagement project compatibility.

This modernized deployment provides enterprise-grade session storage suitable
for production microservices architectures with comprehensive monitoring,
security, and operational capabilities.
