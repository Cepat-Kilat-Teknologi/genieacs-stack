# Contributing to GenieACS Stack

Thank you for your interest in contributing!

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/Cepat-Kilat-Teknologi/genieacs-stack.git`
3. Create a branch: `git checkout -b feature/your-feature`
4. Make your changes
5. Test locally (see below)
6. Push and create a Pull Request

## Local Development

### Prerequisites

- Docker and Docker Compose v2
- Helm 3.16+ (for Helm chart work)
- Make

### Setup

```bash
make setup       # Create .env from .env.example
# Edit .env with your values
make up-d        # Start services
make create-user # Create admin user
make test        # Verify all services
```

### Testing Changes

**Docker image changes:**
```bash
make build       # Build locally
make fresh       # Clean restart with new image
make test        # Verify
```

**CI smoke test:**
The `smoke-test.yml` workflow automatically boots the full stack with Docker Compose and verifies all endpoints on PRs that modify the Dockerfile, config, or scripts.

**Helm chart changes:**
```bash
make lint-helm      # Lint both charts
make helm-template  # Render templates
```

## Code Style

- Use 2-space indentation for YAML files
- Use tab indentation for Makefile recipes
- Follow existing patterns in the codebase
- Keep Docker Compose files consistent across variants

## Pull Request Guidelines

- One logical change per PR
- Update documentation if behavior changes
- Update CHANGELOG.md under `[Unreleased]`
- Ensure `make lint-helm` passes for Helm changes
- Test Docker Compose deployments locally

## Versioning

- Docker image version follows GenieACS upstream
- Helm chart version follows semver independently
- Use the release workflow to bump all version references

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.
