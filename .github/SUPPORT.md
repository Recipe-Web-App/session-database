# Support

Thank you for using Session Database! This document helps you find the
right resources for getting help.

## Documentation

Comprehensive documentation is available:

- **[README.md](../README.md)** - Project overview, features, and quick start
- **[DEPLOYMENT.md](../DEPLOYMENT.md)** - Deployment guides and configuration
- **[CLAUDE.md](../CLAUDE.md)** - Development guide and architecture
  details
- **[CONTAINERMAGAGEMENT.md](../CONTAINERMAGAGEMENT.md)** - Container
  management scripts documentation
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contributing guidelines
- **[SECURITY.md](SECURITY.md)** - Security policy and best practices

## Getting Help

### Decision Tree

```text
Do you have a question?
├─ Yes → Use GitHub Discussions (Q&A)
│
Do you need to report a bug?
├─ Yes → Create a Bug Report issue
│
Do you want to request a feature?
├─ Yes → Create a Feature Request issue
│
Is it a security vulnerability?
├─ Yes (Critical/High) → Use GitHub Security Advisories
└─ Yes (Low) → Create a Security Vulnerability issue
```

## GitHub Discussions

**Best for:** Questions, ideas, general discussion

Use
[GitHub Discussions](https://github.com/Recipe-Web-App/session-database/discussions)
for:

- **Q&A** - Ask questions about usage, configuration, or troubleshooting
- **Ideas** - Share ideas for new features or improvements
- **Show and Tell** - Share your implementations and use cases
- **General** - Community discussions

### Discussion Categories

- **Q&A** - Ask questions and get help from the community
- **Ideas** - Propose new features or improvements
- **Show and Tell** - Share what you've built
- **General** - Everything else

## GitHub Issues

**Best for:** Bug reports, feature requests, tasks

Use [GitHub Issues](https://github.com/Recipe-Web-App/session-database/issues) for:

- **Bug Reports** - Report unexpected behavior or issues
- **Feature Requests** - Suggest new features
- **Performance Issues** - Report performance problems
- **Documentation Issues** - Report doc problems or suggest improvements
- **Tasks** - Track development tasks (maintainers)

### Issue Templates

We provide structured templates:

- [Bug Report](https://github.com/Recipe-Web-App/session-database/issues/new?template=bug_report.yml)
- [Feature Request](https://github.com/Recipe-Web-App/session-database/issues/new?template=feature_request.yml)
- [Performance Issue](https://github.com/Recipe-Web-App/session-database/issues/new?template=performance_issue.yml)
- [Documentation Issue](https://github.com/Recipe-Web-App/session-database/issues/new?template=documentation.yml)
- [Security Vulnerability (Low)](https://github.com/Recipe-Web-App/session-database/issues/new?template=security_vulnerability.yml)

## Security Issues

**For security vulnerabilities:**

- **Critical/High Severity** → Use [GitHub Security Advisories](https://github.com/Recipe-Web-App/session-database/security/advisories/new)
- **Low Severity** → Use [Security Vulnerability template](https://github.com/Recipe-Web-App/session-database/issues/new?template=security_vulnerability.yml)

See [SECURITY.md](SECURITY.md) for details.

## Common Questions

### Getting Started

**Q: How do I deploy Session Database?**

A: See [DEPLOYMENT.md](../DEPLOYMENT.md) for deployment guides. Quick start:

```bash
# Using Helm (recommended)
helm install session-database ./helm/session-database

# Using scripts
./scripts/containerManagement/deploy-container.sh
```

**Q: What are the prerequisites?**

A:

- Kubernetes cluster (1.24+)
- kubectl configured
- Helm 3+ (for Helm deployment)
- Docker (for local development)

**Q: Which deployment mode should I use?**

A:

- **Standalone** - Development/testing only
- **HA Sentinel** - Production deployments (recommended)

### Configuration

**Q: How do I configure Redis authentication?**

A: Create a Kubernetes secret:

```bash
kubectl create secret generic session-database-secret \
  --from-literal=redis-password=YOUR_STRONG_PASSWORD
```

**Q: How do I enable high availability?**

A: Use the Helm chart with HA values:

```bash
helm install session-database ./helm/session-database \
  --values ./helm/session-database/values-production.yaml
```

**Q: How do I enable monitoring?**

A: Monitoring is enabled by default. Access:

```bash
# Prometheus
kubectl port-forward svc/prometheus-service 9090:9090

# Grafana
kubectl port-forward svc/grafana-service 3000:3000
```

### Troubleshooting

#### Q: Redis pods are not starting

A: Check common issues:

1. Verify PVC is bound: `kubectl get pvc`
2. Check pod logs: `kubectl logs -l app=session-database`
3. Verify secret exists: `kubectl get secret session-database-secret`
4. Check resource availability: `kubectl describe node`

#### Q: Sentinel failover not working

A: Verify:

1. Sentinel quorum configured correctly (minimum 3 Sentinels)
2. Network policies allow Sentinel communication
3. Check Sentinel logs: `kubectl logs -l app=redis-sentinel`

#### Q: High memory usage

A: Check:

1. Redis maxmemory configuration
2. Number of sessions stored
3. Persistence settings (AOF/RDB)
4. Monitor with: `./scripts/dbManagement/monitor-auth.sh`

#### Q: Permission denied errors

A: Verify:

1. Pod Security Standards are configured
2. fsGroup is set correctly (999 for Redis)
3. Using PVC instead of hostPath
4. Service account permissions

### Development

**Q: How do I contribute?**

A: See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines. Quick steps:

1. Fork the repository
2. Create a feature branch
3. Make changes and test
4. Run pre-commit hooks
5. Submit a pull request

**Q: How do I run tests?**

A:

```bash
# Validate Kubernetes manifests
kubectl apply --dry-run=client -f k8s/

# Validate Helm chart
helm lint ./helm/session-database

# Run pre-commit hooks
pre-commit run --all-files
```

### Monitoring & Operations

**Q: How do I check cluster health?**

A:

```bash
# Using scripts
./scripts/containerManagement/get-container-status.sh

# Manual check
kubectl get pods,svc,pvc -n session-database
```

**Q: How do I backup Redis data?**

A:

```bash
./scripts/dbManagement/backup-auth.sh all
```

**Q: How do I connect to Redis CLI?**

A:

```bash
# Auth database (DB 0)
./scripts/dbManagement/auth-connect.sh

# Cache database (DB 1)
./scripts/dbManagement/cache-connect.sh
```

## Response Times

We aim for the following response times (best effort, volunteer project):

- **Security Issues (Critical)** - 48 hours
- **Bug Reports** - 1 week
- **Feature Requests** - 2 weeks
- **Questions** - 3-5 days
- **Pull Requests** - 1 week

_Note: These are goals, not guarantees. Response times may vary based on
maintainer availability._

## Community Guidelines

### Asking Good Questions

When asking for help:

1. **Search first** - Check existing issues and discussions
2. **Be specific** - Provide details about your setup
3. **Include context** - Share relevant configuration (redact secrets!)
4. **Show what you tried** - Describe troubleshooting steps
5. **Be respectful** - Follow the Code of Conduct

### Bug Report Best Practices

For effective bug reports:

1. **Clear title** - Summarize the issue concisely
2. **Reproduction steps** - Detailed steps to reproduce
3. **Expected vs Actual** - What should happen vs what happens
4. **Environment details** - K8s version, deployment mode, etc.
5. **Logs** - Include relevant logs (redact sensitive info)
6. **Configuration** - Share relevant config (no secrets!)

Example:

```text
Title: Redis Sentinel fails to detect master failure

Steps to Reproduce:
1. Deploy HA setup with 3 Sentinels
2. Stop Redis master pod
3. Wait 30 seconds
4. Observe: No failover occurs

Expected: Sentinel promotes replica within 10 seconds
Actual: Master remains down, no failover

Environment:
- K8s 1.28
- Redis 7.2
- Sentinel 7.2
- HA mode with 3 Sentinels, quorum=2
```

## Additional Resources

### External Documentation

- **Redis Documentation** - <https://redis.io/docs/>
- **Redis Sentinel** - <https://redis.io/docs/management/sentinel/>
- **Kubernetes Docs** - <https://kubernetes.io/docs/>
- **Helm Docs** - <https://helm.sh/docs/>

### Related Projects

- **OAuth2 Auth Service** - <https://github.com/Recipe-Web-App/auth-service>
- **Recipe Scraper** - <https://github.com/Recipe-Web-App/recipe-scraper>

### Specifications

- **OAuth2 RFC 6749** - <https://tools.ietf.org/html/rfc6749>
- **Redis Protocol** - <https://redis.io/docs/reference/protocol-spec/>

## Need More Help?

If you can't find an answer:

1. **Search** [existing issues](https://github.com/Recipe-Web-App/session-database/issues)
2. **Check** [discussions](https://github.com/Recipe-Web-App/session-database/discussions)
3. **Review** [documentation](../README.md)
4. **Ask** in [Q&A discussions](https://github.com/Recipe-Web-App/session-database/discussions/new?category=q-a)

Thank you for being part of our community! 🙏
