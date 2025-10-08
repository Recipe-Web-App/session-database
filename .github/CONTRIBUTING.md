# Contributing to Session Database

Thank you for your interest in contributing to the Session Database
project! This document provides guidelines for contributing.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting Started

### Prerequisites

- Python 3.11+
- Docker and Docker Compose
- Kubernetes cluster (Minikube or Kind for local development)
- kubectl
- Helm 3+
- Pre-commit hooks

### Development Setup

1. **Fork and clone the repository**

   ```bash
   git clone https://github.com/YOUR_USERNAME/session-database.git
   cd session-database
   ```

2. **Install pre-commit hooks**

   ```bash
   pre-commit install
   pre-commit install --hook-type commit-msg
   ```

3. **Configure Git for conventional commits**

   ```bash
   git config commit.template .gitmessage
   ```

4. **Set up local Kubernetes cluster**

   ```bash
   # Using Minikube
   minikube start

   # Or using Kind
   kind create cluster
   ```

5. **Deploy locally for testing**

   ```bash
   # Using scripts
   ./scripts/containerManagement/deploy-container.sh

   # Or using Helm
   helm install session-database ./helm/session-database
   ```

## Development Workflow

### Branch Strategy

- `main` - Production-ready code
- `develop` - Integration branch for features
- `feature/*` - New features
- `fix/*` - Bug fixes
- `docs/*` - Documentation updates
- `chore/*` - Maintenance tasks

### Making Changes

1. **Create a feature branch**

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Follow the project's coding standards
   - Add tests for new functionality
   - Update documentation as needed

3. **Run pre-commit hooks**

   ```bash
   pre-commit run --all-files
   ```

4. **Commit your changes**
   Use conventional commit format:

   ```bash
   git commit -m "feat: add new Redis configuration option"
   git commit -m "fix: resolve Sentinel failover issue"
   git commit -m "docs: update deployment guide"
   ```

## Testing

### Running Tests

```bash
# Validate Kubernetes manifests
kubectl apply --dry-run=client -f k8s/

# Validate Helm chart
helm lint ./helm/session-database

# Run pre-commit hooks (includes shellcheck, yamllint, etc.)
pre-commit run --all-files

# Test deployment scripts
./scripts/containerManagement/deploy-container.sh
./scripts/containerManagement/get-container-status.sh
```

### Test Guidelines

- Test all Kubernetes manifest changes with dry-run
- Validate Helm chart changes with `helm lint`
- Test scripts with shellcheck
- Verify YAML with yamllint
- Test failover scenarios for HA changes

## Code Style

### Shell Scripts

- Use shellcheck for validation
- Follow bash best practices
- Include error handling
- Add comments for complex logic

```bash
# Good
#!/bin/bash
set -euo pipefail

function deploy_redis() {
    local namespace="${1:-session-database}"
    # Function implementation
}
```

### YAML Files

- Use 2-space indentation
- Follow yamllint rules
- Validate with kubectl/helm
- Use meaningful names and labels

### Documentation

- Update README.md for user-facing changes
- Update CLAUDE.md for development changes
- Add inline comments for complex configurations
- Include examples in documentation

## Commit Guidelines

We use [Conventional Commits](https://www.conventionalcommits.org/)
for automated releases:

### Commit Types

- `feat:` - New features (triggers minor version)
- `fix:` - Bug fixes (triggers patch version)
- `docs:` - Documentation only
- `style:` - Code formatting (no code change)
- `refactor:` - Code refactoring
- `perf:` - Performance improvements
- `test:` - Adding/updating tests
- `chore:` - Maintenance tasks
- `ci:` - CI/CD changes
- `security:` - Security fixes
- `deps:` - Dependency updates

### Commit Format

```text
<type>(<scope>): <subject>

<body>

<footer>
```

**Examples:**

```bash
feat(sentinel): add automatic failover configuration
fix(helm): correct Redis password secret reference
docs(readme): update deployment instructions
perf(redis): optimize memory usage configuration
```

**Breaking Changes:**

```bash
feat!: migrate to Redis 7.0 ACL system

BREAKING CHANGE: Redis ACL configuration now required
```

## Pull Request Process

1. **Update documentation**
   - Update README.md if user-facing changes
   - Update CLAUDE.md if architecture changes
   - Add/update code comments

2. **Fill out PR template**
   - Provide clear description
   - List all changes made
   - Note any breaking changes
   - Include testing details

3. **Ensure CI passes**
   - All pre-commit hooks pass
   - Kubernetes validation succeeds
   - Docker builds successfully

4. **Request review**
   - PRs require approval from maintainers
   - Address review feedback promptly
   - Keep PRs focused and reasonably sized

5. **Merge**
   - Squash and merge preferred for feature branches
   - Maintain clean commit history

## Security

### Reporting Security Issues

**DO NOT** create public issues for security vulnerabilities.

Report security issues through:

- [GitHub Security Advisories](https://github.com/Recipe-Web-App/session-database/security/advisories/new)

See [SECURITY.md](SECURITY.md) for details.

### Security Guidelines

- Never commit secrets or credentials
- Use Kubernetes secrets for sensitive data
- Enable Redis authentication/ACL
- Follow principle of least privilege
- Review network policies for changes

## Project Structure

```text
session-database/
├── .github/              # GitHub configuration
│   ├── workflows/        # CI/CD workflows
│   ├── ISSUE_TEMPLATE/   # Issue templates
│   └── DISCUSSION_TEMPLATE/ # Discussion templates
├── helm/                 # Helm charts
│   └── session-database/
├── k8s/                  # Kubernetes manifests
│   ├── redis/           # Redis deployments
│   ├── prometheus/      # Monitoring
│   └── grafana/         # Dashboards
├── scripts/             # Automation scripts
│   ├── containerManagement/
│   ├── dbManagement/
│   └── jobHelpers/
├── config/              # Configuration files
├── redis/               # Redis configurations
└── docs/                # Documentation
```

## Questions or Help?

- **Documentation**: Check [README.md](../README.md) and [SUPPORT.md](SUPPORT.md)
- **Discussions**: Use [GitHub Discussions](https://github.com/Recipe-Web-App/session-database/discussions)
- **Issues**: Search existing [issues](https://github.com/Recipe-Web-App/session-database/issues)

Thank you for contributing! 🎉
