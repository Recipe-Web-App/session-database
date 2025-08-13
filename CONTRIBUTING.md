# Contributing to Session Database

Thank you for your interest in contributing to the Session Database project!
This document provides guidelines for contributing to this Redis-based session
storage and service cache system.

## Development Setup

### Prerequisites

- Git
- Docker and Docker Compose
- Kubernetes cluster (minikube for local development)
- kubectl
- Helm 3.x
- Python 3.8+ (for pre-commit hooks)
- Node.js (for semantic-release tools)

### Initial Setup

1. **Fork and clone the repository**:

   ```bash
   git clone https://github.com/your-username/session-database.git
   cd session-database
   ```

2. **Install development tools**:

   ```bash
   # Install pre-commit hooks
   pip install pre-commit
   pre-commit install
   pre-commit install --hook-type commit-msg

   # Configure git commit template (optional but recommended)
   git config commit.template .gitmessage
   ```

3. **Set up environment**:

   ```bash
   cp .env.example .env
   # Edit .env with your development configuration
   ```

## Commit Guidelines

This project uses [Conventional Commits](https://www.conventionalcommits.org/)
for consistent commit messages and automated releases.

### Commit Message Format

```text
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Commit Types

| Type       | Description                           | Release Impact     |
| ---------- | ------------------------------------- | ------------------ |
| `feat`     | A new feature                         | Minor version bump |
| `fix`      | A bug fix                             | Patch version bump |
| `docs`     | Documentation only changes            | Patch version bump |
| `style`    | Code style changes (formatting, etc.) | No release         |
| `refactor` | Code refactoring without feature/fix  | Patch version bump |
| `perf`     | Performance improvements              | Patch version bump |
| `test`     | Adding or updating tests              | No release         |
| `build`    | Build system or dependency changes    | Patch version bump |
| `ci`       | CI/CD changes                         | No release         |
| `chore`    | Maintenance tasks                     | No release         |
| `revert`   | Reverting previous commits            | Patch version bump |

### Breaking Changes

For breaking changes, add `!` after the type or `BREAKING CHANGE:` in the footer:

```bash
feat!: migrate to Redis 7.0 with new ACL system

BREAKING CHANGE: Redis ACL authentication is now required.
Update connection strings to include ACL credentials.
```

### Commit Examples

```bash
# Good commit messages
feat: add Redis Sentinel support for high availability
fix(auth): resolve Redis authentication timeout issue
docs: update Helm deployment instructions
perf(cache): optimize Redis connection pooling
test: add integration tests for session cleanup
build(deps): bump Redis image to 8.2-alpine
ci: add automated security scanning workflow

# Breaking change
feat!: remove deprecated standalone Redis setup
```

### Pre-commit Validation

The pre-commit hooks will automatically validate your commit message format.
If your commit message doesn't follow the convention, the commit will be
rejected with helpful guidance.

## Code Quality Standards

### Pre-commit Hooks

All code changes are validated through pre-commit hooks:

- **Security Scanning**: gitleaks, trivy, detect-secrets
- **Code Linting**: shellcheck, yamllint
- **Kubernetes Validation**: kube-score
- **Commit Message**: conventional commits validation

Run all checks before committing:

```bash
pre-commit run --all-files
```

### Code Style

- **Shell Scripts**: Follow shellcheck recommendations
- **YAML Files**: Use 2-space indentation, validated by yamllint
- **Kubernetes Manifests**: Must pass kube-score validation
- **Documentation**: Use clear, concise language with examples

## Testing

### Local Testing

1. **Deploy to local cluster**:

   ```bash
   # Using Helm (recommended)
   helm install session-database ./helm/session-database \
     --namespace session-database --create-namespace

   # Or using scripts
   ./scripts/containerManagement/deploy-container.sh
   ```

2. **Run health checks**:

   ```bash
   ./scripts/jobHelpers/session-health-check.sh
   ./scripts/containerManagement/get-container-status.sh
   ```

3. **Test Redis connections**:

   ```bash
   # Session database (DB 0)
   ./scripts/dbManagement/redis-connect.sh 0

   # Cache database (DB 1)
   ./scripts/dbManagement/redis-connect.sh 1
   ```

### Integration Testing

```bash
# Run integration tests
kubectl apply -f tests/integration/

# Load testing
kubectl apply -f tests/load/
```

## Pull Request Process

### Before Submitting

1. **Create a feature branch**:

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following the guidelines above

3. **Test thoroughly**:

   ```bash
   # Run all pre-commit hooks
   pre-commit run --all-files

   # Test deployment
   helm install test-release ./helm/session-database --dry-run

   # Validate Kubernetes manifests
   kubectl apply --dry-run=client -f k8s/
   ```

4. **Commit with conventional format**:

   ```bash
   git commit -m "feat: add new feature description"
   ```

### Pull Request Guidelines

1. **Title**: Use conventional commit format
2. **Description**: Include:
   - What changes were made and why
   - How to test the changes
   - Any breaking changes or migration notes
   - Screenshots for UI changes (if applicable)

3. **Size**: Keep PRs focused and reasonably sized
4. **Tests**: Include tests for new features or bug fixes
5. **Documentation**: Update relevant documentation

### Example PR Template

```markdown
## Summary

Brief description of the changes made.

## Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing
      functionality to not work as expected)
- [ ] Documentation update

## Testing

- [ ] Local testing completed
- [ ] Integration tests pass
- [ ] Pre-commit hooks pass
- [ ] Manual testing steps (describe any specific testing done)

## Checklist

- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
```

## Release Process

Releases are automated through GitHub Actions based on conventional commits:

### Automatic Releases

- Pushes to `main` branch trigger the release workflow
- Semantic version is calculated from commit types
- Release notes are generated from commit messages
- Docker images and Helm charts are automatically built and published

### Manual Release Testing

```bash
# Install semantic-release tools
npm install -g semantic-release @semantic-release/changelog @semantic-release/git

# Test what would be released (dry run)
npx semantic-release --dry-run

# View upcoming changes
git log --oneline $(git describe --tags --abbrev=0)..HEAD
```

## Security

### Reporting Security Issues

Please report security vulnerabilities privately by emailing the
maintainers. Do not open public issues for security vulnerabilities.

### Security Best Practices

- Never commit secrets, passwords, or API keys
- Use `.env` files for local development (ignored by git)
- Follow the principle of least privilege
- Keep dependencies updated
- Run security scans with pre-commit hooks

## Documentation

### Types of Documentation

1. **Code Comments**: Explain complex logic and decisions
2. **README.md**: User-facing documentation and quick start guide
3. **CLAUDE.md**: Developer guidance for AI assistants
4. **DEPLOYMENT.md**: Detailed deployment instructions
5. **CONTAINERMAGAGEMENT.md**: Script documentation

### Documentation Standards

- Use clear, concise language
- Include practical examples
- Keep documentation up-to-date with code changes
- Use markdown formatting consistently
- Include diagrams for complex architectures

## Getting Help

### Resources

- **Documentation**: Check the README.md and docs/ directory
- **Issues**: Search existing GitHub issues
- **Discussions**: Use GitHub Discussions for questions

### Contact

- Create an issue for bugs or feature requests
- Use discussions for questions and ideas
- Follow the project for updates

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Maintain professional communication

### Enforcement

Instances of unacceptable behavior may be reported to the project
maintainers. All complaints will be reviewed and investigated promptly and
fairly.

Thank you for contributing to the Session Database project!
