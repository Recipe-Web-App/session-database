# Session Database

A Redis-based session storage service designed to provide session storage for microservices.

## Overview

This repository contains a complete Redis database setup for session storage, including:

- Redis server with password authentication
- Kubernetes deployment configuration
- Development and management scripts
- Persistent storage with backup capabilities

## Features

- **Redis Server**: Production-ready Redis 7.2 with password authentication
- **Session Storage**: Persistent session data with TTL support
- **Kubernetes Ready**: Full K8s deployment configuration with Minikube support
- **Development Tools**: Comprehensive scripts for deployment, management, and monitoring
- **Environment Configuration**: Dynamic configuration using environment variables and templates
- **Production Ready**: Complete deployment workflow with health checks and monitoring
- **Security**: Password authentication and network isolation

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Minikube (for local Kubernetes deployment)
- kubectl
- jq (for JSON processing)

### Local Development

1. **Clone and setup**:
   ```bash
   git clone <repository-url>
   cd session-database
   cp env.example .env
   # Edit .env with your configuration
   ```

2. **Start Redis with Docker Compose**:
   ```bash
   docker-compose up -d
   ```

3. **Connect to Redis**:
   ```bash
   ./scripts/dbManagement/redis-connect.sh
   ```

### Kubernetes Development

1. **Setup environment**:
   ```bash
   cp env.example .env
   # Edit .env with your configuration
   ```

2. **Deploy to Minikube**:
   ```bash
   ./scripts/containerManagement/deploy-container.sh
   ```

3. **Check status**:
   ```bash
   ./scripts/containerManagement/get-container-status.sh
   ```

### Kubernetes Deployment

The project includes comprehensive Kubernetes deployment scripts that handle the complete deployment workflow:

1. **Setup environment variables**:
   ```bash
   cp env.example .env
   # Edit .env with your configuration
   ```

2. **Deploy using the deployment script**:
   ```bash
   ./scripts/containerManagement/deploy-container.sh
   ```

This script will:
- ✅ Validate Minikube and required tools
- ✅ Start Minikube if not running
- ✅ Create the namespace
- ✅ Load environment variables from `.env`
- ✅ Build the Docker image inside Minikube
- ✅ Create ConfigMap and Secret from templates
- ✅ Apply PVC, Deployment, and Service
- ✅ Wait for pod readiness
- ✅ Setup Minikube mount for development

#### Container Management Scripts

- **Deploy**: `./scripts/containerManagement/deploy-container.sh` - Complete deployment workflow
- **Start**: `./scripts/containerManagement/start-container.sh` - Scale deployment to 1 replica
- **Stop**: `./scripts/containerManagement/stop-container.sh` - Scale deployment to 0 replicas
- **Status**: `./scripts/containerManagement/get-container-status.sh` - Check deployment status
- **Cleanup**: `./scripts/containerManagement/cleanup-container.sh` - Full cleanup with prompts

## Project Structure

```
session-database/
├── redis/                          # Redis configuration and scripts
│   ├── init/                       # Initialization scripts
│   ├── data/                       # Redis data directory
│   └── queries/                    # Lua scripts for complex operations
├── scripts/                        # Management scripts
│   ├── containerManagement/        # Docker/K8s management
│   │   ├── deploy-container.sh     # Complete deployment workflow
│   │   ├── start-container.sh      # Start deployment
│   │   ├── stop-container.sh       # Stop deployment
│   │   ├── get-container-status.sh # Check status
│   │   └── cleanup-container.sh    # Full cleanup
│   ├── dbManagement/               # Redis operations
│   └── jobHelpers/                 # Maintenance jobs
├── k8s/                            # Kubernetes manifests
│   ├── configmap-template.yaml     # ConfigMap template with env vars
│   ├── secret-template.yaml        # Secret template with env vars
│   ├── deployment.yaml             # Redis deployment
│   ├── service.yaml                # Redis service
│   ├── pvc.yaml                    # Persistent volume claim
│   └── jobs/                       # Kubernetes jobs
└── config/                         # Configuration files
    └── logging.json                # Logging configuration
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
