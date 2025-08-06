# Session Database

An enterprise-grade Redis-based session storage service with high availability, comprehensive security, and production-ready monitoring for microservices architectures.

## Overview

This repository provides a modernized Redis database deployment with enterprise-grade features:

- **High Availability**: Redis Sentinel cluster with automatic failover
- **Comprehensive Security**: Network policies, TLS encryption, ACL authentication
- **Advanced Monitoring**: Prometheus, Grafana, Alertmanager with 15+ alerting rules
- **Automated Operations**: Session cleanup CronJob and health monitoring
- **Infrastructure as Code**: Helm charts with GitOps workflow via ArgoCD
- **Production Ready**: Kubernetes-native deployment with security hardening

## Architecture

### Core Components
- **Redis Sentinel HA**: 3-node Sentinel cluster monitoring master-replica setup
- **Redis Master**: Primary instance with persistent storage (10-50GB)
- **Redis Replicas**: 2-3 read replicas for load distribution and failover
- **Session Management**: TTL-based sessions with automated cleanup every 5 minutes
- **Token Systems**: Refresh tokens and deletion tokens with separate TTL management

### Security & Monitoring
- **Network Policies**: Strict pod-to-pod communication rules
- **Pod Security Standards**: Enforced "restricted" security profile
- **TLS Encryption**: Optional Redis connection encryption
- **ACL Authentication**: Role-based Redis access (6 user types)
- **Comprehensive Monitoring**: Prometheus, Grafana, Alertmanager stack
- **Automated Alerting**: 15+ critical and warning alerts for proactive response

### Deployment Options
- **Helm Charts**: Production-ready Kubernetes deployment
- **GitOps**: ArgoCD integration with multi-environment support
- **Script-based**: containerManagement scripts for development (standalone mode)
- **Manual HA**: Full HA deployment with Redis master, replicas, and Sentinel available via raw manifests

## Features

- **High Availability**: Sub-minute automatic failover with zero data loss
- **Session Storage**: Persistent session data with configurable TTL (1-24 hours)
- **Token Management**: Refresh tokens (7-14 days) and deletion tokens
- **Auto-scaling**: HPA based on CPU (70%) and memory (80%) thresholds
- **Backup & Recovery**: Automated backup with point-in-time recovery
- **Security Hardening**: Multi-layer security with network isolation
- **Performance Optimized**: Memory management and connection pooling

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
   ```

## Deployment Options

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

The containerManagement scripts provide consistent deployment patterns across the distributed system:

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

```
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

# Connect to Redis
redis_client = redis.Redis(
    host='session-database-service.session-database.svc.cluster.local',
    port=6379,
    password='redis_password',  # pragma: allowlist secret
    decode_responses=True
)

# Direct Redis operations
redis_client.setex(f"session:{session_id}", 3600, session_data)
session_data = redis_client.get(f"session:{session_id}")
redis_client.delete(f"session:{session_id}")
```

### Management Scripts

#### Container Management
- **Deploy**: `./scripts/containerManagement/deploy-container.sh` - Complete deployment workflow
- **Start**: `./scripts/containerManagement/start-container.sh` - Scale deployment to 1 replica
- **Stop**: `./scripts/containerManagement/stop-container.sh` - Scale deployment to 0 replicas
- **Status**: `./scripts/containerManagement/get-container-status.sh` - Check deployment status
- **Cleanup**: `./scripts/containerManagement/cleanup-container.sh` - Full cleanup with prompts
- **Monitoring**: `./scripts/containerManagement/deploy-monitoring.sh` - Deploy monitoring stack
- **Monitoring Cleanup**: `./scripts/containerManagement/cleanup-monitoring.sh` - Cleanup monitoring stack

#### Database Management
- **Connect to Redis**: `./scripts/dbManagement/redis-connect.sh`
- **Backup sessions**: `./scripts/dbManagement/backup-sessions.sh`
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

# Session Configuration
SESSION_TTL_SECONDS=3600
MAX_SESSIONS_PER_USER=5
CLEANUP_INTERVAL_SECONDS=300
LOG_LEVEL=INFO
```

The deployment scripts use environment variable substitution for ConfigMap and Secret templates, making configuration dynamic and secure.

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
   ```

2. **Run tests**:
   ```bash
   # Test Redis connection
kubectl exec -n session-database <pod-name> -- redis-cli -a redis_password ping  # pragma: allowlist secret
   ```

### Code Quality

The project uses several tools to maintain code quality:

- **ShellCheck**: Shell script linting
- **pre-commit**: Automated checks

## Monitoring

### Monitoring Stack

The project includes a comprehensive monitoring stack with Prometheus, Grafana, and security monitoring:

#### Deploy Monitoring Stack

```bash
# Deploy all monitoring components
./scripts/containerManagement/deploy-monitoring.sh
```

This deploys:
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Redis Exporter**: Redis metrics collection

#### Access Monitoring Tools

- **Prometheus**: http://prometheus.local
- **Grafana**: http://grafana.local (admin/admin)

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
kubectl exec -n session-database <pod-name> -- redis-cli -a redis_password info  # pragma: allowlist secret

# Get memory usage
kubectl exec -n session-database <pod-name> -- redis-cli -a redis_password info memory  # pragma: allowlist secret

# Get session keys
kubectl exec -n session-database <pod-name> -- redis-cli -a redis_password KEYS "session:*"  # pragma: allowlist secret
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

# Connect to the session database
redis_client = redis.Redis(
    host='session-database-service.session-database.svc.cluster.local',
    port=6379,
    password='redis_password',  # pragma: allowlist secret
    decode_responses=True
)

# Direct Redis operations for session management
redis_client.setex(f"session:{session_id}", 3600, session_data)
session_data = redis_client.get(f"session:{session_id}")
```

### Key Integration Points

- **Session Storage**: Store session data with TTL
- **Session Retrieval**: Get session data by ID
- **Session Cleanup**: Handle expired sessions
- **User Session Tracking**: Track multiple sessions per user

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
