# Session Database

A Redis-based session management system designed to handle user sessions for the user-manager-service.

## Overview

This repository contains a complete Redis database setup for managing user sessions, including:

- Session creation, validation, and cleanup
- User session tracking
- Automatic expiration handling
- Kubernetes deployment configuration
- Development and management scripts

## Features

- **Session Management**: Complete session lifecycle with TTL support
- **User Session Tracking**: Multiple sessions per user with cleanup
- **Automatic Cleanup**: Expired session cleanup using Redis sorted sets
- **Statistics**: Session monitoring and statistics
- **Kubernetes Ready**: Full K8s deployment configuration with Minikube support
- **Development Tools**: Comprehensive scripts for deployment, management, and monitoring
- **Environment Configuration**: Dynamic configuration using environment variables and templates
- **Production Ready**: Complete deployment workflow with health checks and monitoring

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Minikube (for local Kubernetes deployment)
- kubectl
- Python 3.8+ (for development tools)
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
├── python/                         # Python client and utilities
│   ├── session_manager.py          # Main session management class
│   ├── session_client.py           # Redis client wrapper
│   └── utils/                      # Utility modules
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
└── tests/                          # Test suite
```

## Usage

### Python Client

```python
import redis
from python.session_manager import SessionManager

# Connect to Redis
redis_client = redis.Redis(
    host='localhost',
    port=6379,
    password='your_password', # pragma: allowlist secret
    decode_responses=True
)

session_manager = SessionManager(redis_client)

# Create a session
session = session_manager.create_session(
    user_id="user123",
    ttl_seconds=3600,
    metadata={"ip": "192.168.1.1", "user_agent": "Mozilla/5.0..."}
)

# Get session
session_data = session_manager.get_session(session.session_id)

# Invalidate session
session_manager.invalidate_session(session.session_id)

# Get user's active sessions
user_sessions = session_manager.get_user_sessions("user123")

# Cleanup expired sessions
cleaned_count = session_manager.cleanup_expired_sessions()
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

### Example Usage

Run the included example to see the session management system in action:

```bash
python example_usage.py
```

This demonstrates:
- Session creation and retrieval
- User session tracking
- Session invalidation
- Statistics and monitoring
- Cleanup operations

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

2. **Install Python dependencies**:
   ```bash
   cd python
   pip install -r requirements.txt
   ```

3. **Run tests**:
   ```bash
   pytest tests/
   ```

### Code Quality

The project uses several tools to maintain code quality:

- **Black**: Code formatting
- **isort**: Import sorting
- **flake8**: Linting
- **mypy**: Type checking
- **pre-commit**: Automated checks

## Monitoring

### Session Statistics

```python
stats = session_manager.get_session_stats()
print(f"Total sessions: {stats['total_sessions']}")
print(f"Active sessions: {stats['active_sessions']}")
print(f"Expired sessions: {stats['expired_sessions']}")
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

## Integration with User-Manager-Service

This session database is designed to work seamlessly with your user-manager-service:

### Connection Setup

```python
# In your user-manager-service
from session_database.python.session_manager import SessionManager
import redis

# Connect to the session database
redis_client = redis.Redis(
    host='session-database-service.session-database.svc.cluster.local',
    port=6379,
    password='your_redis_password', # pragma: allowlist secret
    decode_responses=True
)

session_manager = SessionManager(redis_client)
```

### Key Integration Points

- **Session Creation**: Create sessions when users log in
- **Session Validation**: Validate sessions on each request
- **Session Cleanup**: Automatically handle expired sessions
- **User Session Management**: Track multiple sessions per user

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
