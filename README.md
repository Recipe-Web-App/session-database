# Session Database

An enterprise-grade Redis-based session storage and service cache system with
high availability, comprehensive security, and production-ready monitoring for
microservices architectures.

## Overview

This repository provides a modernized Redis database deployment with
enterprise-grade features:

- **Multi-Database Architecture**: Isolated databases for sessions (DB 0)
  and service cache (DB 1)
- **High Availability**: Redis Sentinel cluster with automatic failover
- **Comprehensive Security**: Network policies, TLS encryption, ACL authentication
- **Advanced Monitoring**: Prometheus, Grafana, Alertmanager with 20+ alerting rules
- **Automated Operations**: Session and cache cleanup CronJobs with TTL-based expiration
- **Infrastructure as Code**: Helm charts with GitOps workflow via ArgoCD
- **Production Ready**: Kubernetes-native deployment with security hardening

## Architecture

### Core Components

- **Redis Sentinel HA**: 3-node Sentinel cluster monitoring master-replica setup
- **Redis Master**: Primary instance with persistent storage (10-50GB)
- **Redis Replicas**: 2-3 read replicas for load distribution and failover
- **Session Management**: TTL-based sessions with automated cleanup
  every 5 minutes (DB 0)
- **Service Cache**: TTL-based caching system for resource data (DB 1)
- **Token Systems**: Refresh tokens and deletion tokens with separate TTL management

### Security & Monitoring

- **Network Policies**: Strict pod-to-pod communication rules
- **Pod Security Standards**: Enforced "restricted" security profile
- **TLS Encryption**: Optional Redis connection encryption
- **ACL Authentication**: Role-based Redis access (7 user types
  including cache)
- **Comprehensive Monitoring**: Prometheus, Grafana, Alertmanager stack
  with dual Redis exporters
- **Automated Alerting**: 20+ critical and warning alerts for proactive response

### Available Deployment Methods

- **Helm Charts**: Production-ready Kubernetes deployment
- **GitOps**: ArgoCD integration with multi-environment support
- **Script-based**: containerManagement scripts for development (standalone mode)
- **Manual HA**: Full HA deployment with Redis master, replicas, and
  Sentinel available via raw manifests

## Features

- **High Availability**: Sub-minute automatic failover with zero data loss
- **Session Storage**: Persistent session data with configurable TTL (1-24 hours)
- **Service Cache**: Isolated cache database for resource data with
  TTL-based expiration
- **Token Management**: Refresh tokens (7-14 days) and deletion tokens
- **Auto-scaling**: HPA based on CPU (70%) and memory (80%) thresholds
- **Backup & Recovery**: Multi-database backup with point-in-time recovery
- **Security Hardening**: Multi-layer security with network isolation
- **Performance Optimized**: Independent memory management and
  connection pooling per database

## Quick Start

### Prerequisites

**For Script-based Deployment:**

- Docker and Docker Compose
- Minikube (for local development)
- kubectl and jq

**For Helm Deployment:**

- Kubernetes cluster (1.25+)
- Helm 3.x
- kubectl configured

**For GitOps Deployment:**

- ArgoCD installed in cluster
- Git repository access

### Environment Setup

1. **Clone and configure**:

   ```bash
   git clone <repository-url>
   cd session-database
   cp .env.example .env
   # Edit .env with your secure passwords (6 password types required)
   ```

2. **Environment Variables** (All Required):

   ```bash
   # Core Redis Authentication
   REDIS_PASSWORD=your-secure-redis-password
   SENTINEL_PASSWORD=your-secure-sentinel-password

   # ACL User Passwords (role-based access)
   APP_PASSWORD=your-app-password          # Application access
   MONITOR_PASSWORD=your-monitor-password  # Prometheus monitoring
   CLEANUP_PASSWORD=your-cleanup-password  # Cleanup job access
   BACKUP_PASSWORD=your-backup-password    # Backup operations
   CACHE_PASSWORD=your-cache-password      # Service cache operations
   ```

## Deployment Guide

### Option 1: Script-based Deployment (Development/Legacy)

1. **Deploy Redis HA cluster**:

   ```bash
   ./scripts/containerManagement/deploy-container.sh
   ```

2. **Deploy monitoring and security**:

   ```bash
   ./scripts/containerManagement/deploy-monitoring.sh
   ```

3. **Check status**:

   ```bash
   ./scripts/containerManagement/get-container-status.sh
   ```

### Option 2: Helm Deployment (Recommended)

1. **Development deployment**:

   ```bash
   helm install session-database ./helm/session-database \
     --namespace session-database --create-namespace \
     --set redis.auth.password=your-redis-password \
     --set redis.auth.sentinel.password=your-sentinel-password
   ```

2. **Production deployment**:

   ```bash
   helm install session-database ./helm/session-database \
     --namespace session-database --create-namespace \
     --values ./helm/session-database/values-production.yaml
   ```

### Option 3: GitOps with ArgoCD (Production)

1. **Deploy ArgoCD Application**:

   ```bash
   kubectl apply -f k8s/argocd/application.yaml
   ```

2. **Multi-environment setup**:

   ```bash
   kubectl apply -f k8s/argocd/applicationset.yaml
   ```

## Container Management Scripts

The containerManagement scripts provide consistent deployment patterns
across the distributed system:

### Core Container Scripts (Redis Cluster)

- **`deploy-container.sh`**: Deploy Redis HA cluster (Master, Replicas, Sentinel)
- **`start-container.sh`**: Start Redis cluster components
- **`stop-container.sh`**: Stop Redis cluster components
- **`cleanup-container.sh`**: Clean up Redis cluster with data preservation options
- **`get-container-status.sh`**: Check Redis cluster health and status

### Supporting Services Scripts (Monitoring & Security)

- **`deploy-monitoring.sh`**: Deploy monitoring, alerting, and security
- **`cleanup-monitoring.sh`**: Clean up monitoring and security components

### Usage Examples

```bash
# Full deployment workflow
./scripts/containerManagement/deploy-container.sh
./scripts/containerManagement/deploy-monitoring.sh

# Check status
./scripts/containerManagement/get-container-status.sh

# Maintenance operations
./scripts/containerManagement/stop-container.sh    # Maintenance mode
./scripts/containerManagement/start-container.sh   # Resume operations

# Clean removal (proper order)
./scripts/containerManagement/cleanup-monitoring.sh   # Cleanup monitoring first
./scripts/containerManagement/cleanup-container.sh    # Then cleanup Redis
```

## Monitoring & Operations

### Access Monitoring Tools

```bash
# Development (port-forward)
kubectl port-forward svc/prometheus-service -n session-database 9090:9090
kubectl port-forward svc/grafana-service -n session-database 3000:3000
kubectl port-forward svc/alertmanager-service -n session-database 9093:9093

# Production (ingress)
# https://prometheus.session-db.example.com
# https://grafana.session-db.example.com
```

### Key Metrics & Alerts

- **Redis Cluster Health**: Master/replica/sentinel status
- **Session Management**: Active sessions, cleanup success rate
- **Performance**: Memory usage, connection count, hit rate
- **Security**: Network policy enforcement, authentication failures
- **15+ Automated Alerts**: Critical and warning notifications

## Project Structure

```text
session-database/
├── helm/                           # Helm charts (recommended deployment)
│   └── session-database/           # Main Helm chart
│       ├── Chart.yaml              # Chart metadata
│       ├── values.yaml             # Default configuration
│       ├── values-production.yaml  # Production overrides
│       └── templates/              # Kubernetes templates
├── k8s/                           # Kubernetes manifests (organized by application)
│   ├── argocd/                     # GitOps configurations
│   │   ├── application.yaml        # ArgoCD application
│   │   ├── applicationset.yaml     # Multi-environment setup
│   │   └── session-database-project-appproject.yaml
│   ├── redis/                      # Redis session database
│   │   ├── standalone/             # Simple deployment option
│   │   │   ├── deployment.yaml     # Single Redis instance
│   │   │   ├── service.yaml        # Redis service
│   │   │   └── pvc.yaml           # Persistent storage
│   │   ├── ha/                     # High availability deployment
│   │   │   ├── master/             # Redis master components
│   │   │   ├── replica/            # Redis replica components
│   │   │   └── sentinel/           # Redis sentinel components
│   │   ├── shared/                 # Shared Redis resources
│   │   │   └── session-cleanup-*   # Automated cleanup jobs
│   │   └── autoscaling/           # Redis auto-scaling
│   │       └── hpa.yaml           # Horizontal pod autoscaler
│   ├── prometheus/                 # Prometheus monitoring
│   │   ├── prometheus-deployment.yaml
│   │   ├── prometheus-service.yaml
│   │   ├── prometheus-config.yaml
│   │   ├── prometheus-alerting-rules.yaml
│   │   └── redis-exporter/         # Redis metrics collection
│   │       ├── deployment.yaml
│   │       └── service.yaml
│   ├── grafana/                    # Grafana visualization
│   │   ├── grafana-deployment.yaml
│   │   ├── grafana-service.yaml
│   │   ├── grafana-dashboards-config.yaml
│   │   └── grafana-datasources-config.yaml
│   ├── alertmanager/               # Alert management
│   │   ├── alertmanager-deployment.yaml
│   │   ├── alertmanager-service.yaml
│   │   └── alertmanager-config.yaml
│   ├── shared/                     # Cross-application resources
│   │   ├── podsecurity.yaml        # Pod security standards
│   │   ├── networkpolicy.yaml      # Network policies
│   │   ├── ingress.yaml           # Ingress configuration
│   │   └── tls-certificates.yaml  # TLS certificates
│   └── templates/                  # Template files
│       ├── configmap-template.yaml
│       └── secret-template.yaml
├── scripts/                        # Management scripts
│   ├── containerManagement/        # Deployment scripts
│   │   ├── deploy-container.sh     # Deploy Redis components
│   │   ├── deploy-monitoring.sh      # Deploy monitoring/security
│   │   ├── start-container.sh      # Start services
│   │   ├── stop-container.sh       # Stop services
│   │   ├── get-container-status.sh # Check status
│   │   ├── cleanup-container.sh    # Cleanup Redis
│   │   └── cleanup-monitoring.sh   # Cleanup monitoring
│   ├── dbManagement/               # Database operations
│   └── jobHelpers/                 # Health checks and utilities
├── redis/                          # Redis configuration
│   ├── init/scripts/               # Lua initialization scripts
│   └── data/                       # Redis data directory
└── docs/                          # Documentation
    ├── DEPLOYMENT.md               # Comprehensive deployment guide
    └── CONTAINERMAGAGEMENT.md     # Script documentation
```

## Usage

### Redis Connection

Connect to the Redis server from your applications:

```python
import redis

# Connect to Session Database (DB 0)
session_client = redis.Redis(
    host='session-database-service.session-database.svc.cluster.local',
    port=6379,
    password='redis_password',  # pragma: allowlist secret
    db=0,  # Session database
    decode_responses=True
)

# Connect to Cache Database (DB 1)
cache_client = redis.Redis(
    host='session-database-service.session-database.svc.cluster.local',
    port=6379,
    password='redis_password',  # pragma: allowlist secret
    db=1,  # Cache database
    decode_responses=True
)

# Session operations (DB 0)
session_client.setex(f"session:{session_id}", 3600, session_data)
session_data = session_client.get(f"session:{session_id}")
session_client.delete(f"session:{session_id}")

# Cache operations (DB 1) - Example from recipe scraper service
cache_client.setex(f"cache:resource:popular_recipes", 86400, recipe_data)
recipe_data = cache_client.get(f"cache:resource:popular_recipes")
```

### Management Scripts

#### Container Management

- **Deploy**: `./scripts/containerManagement/deploy-container.sh` -
  Complete deployment workflow
- **Start**: `./scripts/containerManagement/start-container.sh` -
  Scale deployment to 1 replica
- **Stop**: `./scripts/containerManagement/stop-container.sh` -
  Scale deployment to 0 replicas
- **Status**: `./scripts/containerManagement/get-container-status.sh` -
  Check deployment status
- **Cleanup**: `./scripts/containerManagement/cleanup-container.sh` -
  Full cleanup with prompts
- **Monitoring**: `./scripts/containerManagement/deploy-monitoring.sh` -
  Deploy monitoring stack
- **Monitoring Cleanup**:
  `./scripts/containerManagement/cleanup-monitoring.sh` -
  Cleanup monitoring stack

#### Database Management

- **Connect to Redis**: `./scripts/dbManagement/redis-connect.sh [0|1]`
  (DB 0=sessions, DB 1=cache)
- **Cache-specific connection**: `./scripts/dbManagement/cache-connect.sh`
- **Backup databases**:
  `./scripts/dbManagement/backup-sessions.sh [all|sessions|cache]`
- **Cache information**: `./scripts/dbManagement/show-cache-info.sh`
- **Monitor sessions**: `./scripts/dbManagement/monitor-sessions.sh`
- **Health check**: `./scripts/jobHelpers/session-health-check.sh`

## Configuration

### Environment Variables

Key configuration options in `.env`:

```env
# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password_here
REDIS_DB=0
CACHE_DB=1

# Session Configuration
SESSION_TTL_SECONDS=3600
MAX_SESSIONS_PER_USER=5
CLEANUP_INTERVAL_SECONDS=300

# Service Cache Configuration
CACHE_DEFAULT_TTL_SECONDS=86400
CACHE_CLEANUP_INTERVAL_SECONDS=600
CACHE_CLEANUP_BATCH_SIZE=200
CACHE_MAX_ENTRIES_PER_SERVICE=10000

LOG_LEVEL=INFO
```

The deployment scripts use environment variable substitution for ConfigMap
and Secret templates, making configuration dynamic and secure.

### Redis Configuration

The Redis configuration is optimized for session management:

- **Memory Management**: 256MB max memory with LRU eviction
- **Persistence**: AOF enabled for session durability
- **Performance**: Optimized for session operations

## Development

### Setup Development Environment

1. **Install pre-commit hooks**:

   ```bash
   pip install pre-commit
   pre-commit install
   pre-commit install --hook-type commit-msg
   ```

2. **Configure git commit template** (optional):

   ```bash
   git config commit.template .gitmessage
   ```

3. **Run tests**:

   ```bash
   # Test Redis connection
   kubectl exec -n session-database <pod-name> -- \
     redis-cli -a redis_password ping  # pragma: allowlist secret
   ```

### Commit Message Convention

This project uses [Conventional Commits](https://www.conventionalcommits.org/)
for consistent commit messages and automated releases.

#### Commit Message Format

```text
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

#### Types

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `build`: Changes that affect the build system or external dependencies
- `ci`: Changes to our CI configuration files and scripts
- `chore`: Other changes that don't modify src or test files
- `revert`: Reverts a previous commit

#### Examples

```bash
feat: add Redis Sentinel support for high availability
fix(auth): resolve Redis authentication timeout issue
docs: update deployment guide with Helm instructions
feat!: remove deprecated standalone Redis setup
```

#### Breaking Changes

Add `BREAKING CHANGE:` in the footer or `!` after the type/scope for breaking changes:

```bash
feat!: migrate to Redis 7.0 with new ACL system

BREAKING CHANGE: Redis ACL authentication is now required.
Update your connection strings to include ACL credentials.
```

### Automated Releases

The project uses automated semantic versioning and releases based on
conventional commits:

#### Release Triggers

- **Patch**: `fix`, `perf`, `docs`, `refactor`, `build` commits
- **Minor**: `feat` commits
- **Major**: Any commit with `BREAKING CHANGE:` or `!` suffix

#### Release Artifacts

Each release automatically generates:

1. **Git Tag**: Semantic version (e.g., `v1.2.3`)
2. **GitHub Release**: Release notes from commit messages
3. **Docker Images**: Multi-arch images pushed to GitHub Container Registry
   - `ghcr.io/recipe-web-app/session-database:latest`
   - `ghcr.io/recipe-web-app/session-database:v1.2.3`
4. **Helm Chart**: Packaged chart attached to GitHub release
5. **Changelog**: Auto-generated `CHANGELOG.md` with categorized changes

#### Release Workflow

1. **Commit**: Use conventional commit format
2. **Push to main**: Triggers automated release workflow
3. **Semantic Release**: Analyzes commits and determines version bump
4. **Artifacts**: Docker images and Helm charts are built and published
5. **Documentation**: Changelog and release notes are updated

#### Manual Release

To trigger a release manually or test locally:

```bash
# Install semantic-release tools
npm install -g semantic-release @semantic-release/changelog @semantic-release/git

# Dry run (shows what would be released)
npx semantic-release --dry-run

# Create release (CI does this automatically)
npx semantic-release
```

### Code Quality

The project uses several tools to maintain code quality:

- **ShellCheck**: Shell script linting
- **pre-commit**: Automated checks

## Monitoring

### Monitoring Stack

The project includes a comprehensive monitoring stack with Prometheus,
Grafana, and security monitoring:

#### Deploy Monitoring Stack

```bash
# Deploy all monitoring components
./scripts/containerManagement/deploy-monitoring.sh
```

This deploys:

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Redis Exporter**: Redis metrics collection

#### Access Monitoring Dashboard Tools

- **Prometheus**: <http://prometheus.local>
- **Grafana**: <http://grafana.local> (admin/admin)

**Setup Access:**
The deployment script automatically updates `/etc/hosts` for easy access.

**Manual options:**

1. **Option 1**: Add to `/etc/hosts`:

   ```bash
   $(minikube ip) prometheus.local grafana.local
   ```

2. **Option 2**: Use Minikube tunnel:

   ```bash
   sudo minikube tunnel
   ```

#### Monitoring Components

**Prometheus Configuration** (`k8s/monitoring/prometheus.yaml`):

- Scrapes Redis metrics via redis-exporter
- Stores metrics with 200h retention
- Configurable scrape intervals

**Grafana Dashboards** (`k8s/monitoring/grafana-dashboards-config.yaml`):

- Redis monitoring dashboard
- Memory usage, connected clients
- Commands per second, keyspace hits

**Redis Exporter** (`k8s/monitoring/redis-exporter.yaml`):

- Exposes Redis metrics to Prometheus
- Authenticated connection to Redis
- Custom metrics for session management

### Redis Statistics

```bash
# Get Redis info
kubectl exec -n session-database <pod-name> -- \
  redis-cli -a redis_password info  # pragma: allowlist secret

# Get memory usage
kubectl exec -n session-database <pod-name> -- \
  redis-cli -a redis_password info memory  # pragma: allowlist secret

# Get session keys
kubectl exec -n session-database <pod-name> -- \
  redis-cli -a redis_password KEYS "session:*"  # pragma: allowlist secret
```

### Health Checks

The Redis container includes health checks:

- **Liveness Probe**: Redis ping every 30s
- **Readiness Probe**: Redis ping every 5s

## Security

### Authentication

- Redis password authentication
- Kubernetes secrets for sensitive data
- Network policies for access control

### Data Protection

- Session data encryption in transit
- Secure session ID generation
- Automatic session expiration

## Troubleshooting

### Common Issues

1. **Connection refused**: Check if Redis is running
2. **Authentication failed**: Verify Redis password
3. **Memory issues**: Check Redis memory usage and eviction policy

### Logs

- **Redis logs**: `/logs/redis.log` in container
- **Application logs**: Check Kubernetes pod logs

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and linting
5. Submit a pull request

## Integration with Microservices

This session database is designed to work seamlessly with your microservices:

### Connection Setup

```python
# In your microservices
import redis

# Connect to session database (DB 0)
session_client = redis.Redis(
    host='session-database-service.session-database.svc.cluster.local',
    port=6379,
    password='redis_password',  # pragma: allowlist secret
    db=0,  # Session database
    decode_responses=True
)

# Connect to cache database (DB 1)
cache_client = redis.Redis(
    host='session-database-service.session-database.svc.cluster.local',
    port=6379,
    password='redis_password',  # pragma: allowlist secret
    db=1,  # Cache database
    decode_responses=True
)

# Session management operations (DB 0)
session_client.setex(f"session:{session_id}", 3600, session_data)
session_data = session_client.get(f"session:{session_id}")

# Service cache operations (DB 1) - Recipe scraper example
cache_client.setex(f"cache:resource:popular_recipes", 86400, recipe_data)
```

### Key Integration Points

#### Session Management (DB 0)

- **Session Storage**: Store session data with TTL
- **Session Retrieval**: Get session data by ID
- **Session Cleanup**: Handle expired sessions
- **User Session Tracking**: Track multiple sessions per user

#### Service Cache (DB 1)

- **Resource Cache**: Currently used by recipe scraper service
  (`cache:resource:popular_recipes`)
- **Simple TTL-based**: 24-hour cache expiration with automatic
  cleanup
- **Extensible**: Additional cache patterns can be added following
  `cache:resource:*` format

## License

This project is licensed under the GNU General Public License v3.0 -
see the [LICENSE](LICENSE) file for details.
