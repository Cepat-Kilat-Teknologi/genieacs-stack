# GenieACS Stack

[![ci](https://github.com/Cepat-Kilat-Teknologi/genieacs-stack/actions/workflows/docker-build.yml/badge.svg?branch=main)](https://github.com/Cepat-Kilat-Teknologi/genieacs-stack/actions/workflows/docker-build.yml)
[![Helm](https://github.com/Cepat-Kilat-Teknologi/genieacs-stack/actions/workflows/helm-release.yml/badge.svg)](https://github.com/Cepat-Kilat-Teknologi/genieacs-stack/actions/workflows/helm-release.yml)
[![Smoke Test](https://github.com/Cepat-Kilat-Teknologi/genieacs-stack/actions/workflows/smoke-test.yml/badge.svg)](https://github.com/Cepat-Kilat-Teknologi/genieacs-stack/actions/workflows/smoke-test.yml)
![GenieACS](https://img.shields.io/badge/GenieACS-1.2.16-orange?style=flat-square)
![MongoDB](https://img.shields.io/badge/MongoDB-8.0-green?style=flat-square)
![Multi-Arch](https://img.shields.io/badge/multi--arch-amd64%2Carm64-lightgrey?style=flat-square)

Complete deployment stack for [GenieACS](https://genieacs.com) v1.2.16 with MongoDB 8.0. Supports Docker Compose, Kubernetes, and Helm deployments with optional NBI API authentication.

## Features

- **GenieACS v1.2.16** - CWMP, NBI, FS, UI services
- **MongoDB 8.0** - Database with authentication and health checks
- **Multiple Deployment Options** - Docker Compose, Kubernetes (Kustomize), Helm Charts
- **NBI API Authentication** - Optional X-API-Key protection via Nginx proxy
- **MongoDB Authentication** - Secure database access with username/password
- **Multi-architecture** - amd64, arm64 support
- **Note:** ARMv7 (32-bit ARM) is not supported — Node.js 24 dropped official ARMv7 binaries
- **Helm Chart Tests** - Post-install verification via `helm test`
- **MongoDB Backup CronJob** - Optional scheduled backups (Helm)
- **Cert-manager Ingress** - TLS termination with cert-manager examples
- **Production Ready** - NetworkPolicy isolation, health monitoring, log rotation, data persistence
- **CI/CD** - Multi-arch build, Trivy scanning, cosign signing, Helm OCI push, Dependabot, smoke test workflow

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   GenieACS Container                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │
│  │   CWMP   │ │   NBI    │ │    FS    │ │   UI   │ │
│  │  :7547   │ │  :7557   │ │  :7567   │ │ :3000  │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └───┬────┘ │
│       │             │            │            │      │
│       └─────────────┴────────────┴────────────┘      │
│                         │                            │
│                   supervisord                        │
└─────────────────────────┬───────────────────────────┘
                          │
                    ┌─────┴─────┐
                    │  MongoDB  │
                    │   :27017  │
                    └───────────┘

Optional NBI Authentication (nbi-auth variant):

CPE ──► CWMP :7547 ──► GenieACS
API ──► Nginx :7558 ──► NBI :7557 ──► GenieACS
        (X-API-Key)
Web ──► UI :3000 ──► GenieACS
```

## Quick Start

### Using Docker Compose

```bash
git clone https://github.com/Cepat-Kilat-Teknologi/genieacs-stack.git
cd genieacs-stack

make setup        # Creates .env from template
# Edit .env and set secure secrets (use: openssl rand -hex 32)

make build        # Build the Docker image locally
make up-d         # Start MongoDB + GenieACS
make create-user  # Create admin user + permissions + default config
```

Access: http://localhost:3000 (login with credentials from `.env`)

### Using Helm

```bash
# Add repository
helm repo add genieacs https://cepat-kilat-teknologi.github.io/genieacs-stack
helm repo update

# Install with secure secrets
helm install genieacs genieacs/genieacs \
  --namespace genieacs \
  --create-namespace \
  --set secret.jwtSecret="$(openssl rand -hex 32)" \
  --set mongodb.auth.rootPassword="$(openssl rand -base64 24)"
```

### Using Kubernetes (Kustomize)

```bash
cd examples/default/kubernetes
# Edit secret.yaml with your JWT secret
# Edit mongodb-secret.yaml with your MongoDB credentials
# Edit configmap.yaml to match MongoDB credentials
kubectl apply -k .
```

> **Full installation guide**: See [INSTALLATION.md](INSTALLATION.md)

## Available Deployments

| Type | Default | With NBI Auth | Description |
|------|---------|---------------|-------------|
| Docker | `examples/default/docker/` | `examples/nbi-auth/docker/` | Docker Compose |
| Kubernetes | `examples/default/kubernetes/` | `examples/nbi-auth/kubernetes/` | Kustomize manifests |
| Helm | `genieacs/genieacs` | `genieacs/genieacs-nbi-auth` | Helm charts |
| ArgoCD | `examples/argocd/genieacs-app.yaml` | `examples/argocd/genieacs-nbi-auth-app.yaml` | GitOps (requires ArgoCD) |

## Services & Ports

| Service | Port | Description |
|---------|------|-------------|
| Web UI | 3000 | Management interface |
| CWMP | 7547 | TR-069 for CPE devices |
| NBI API | 7557 | Northbound Interface |
| File Server | 7567 | Firmware uploads |

## Documentation

| Document | Description |
|----------|-------------|
| [INSTALLATION.md](INSTALLATION.md) | Complete installation guide for all platforms |
| [SECURITY.md](SECURITY.md) | Security best practices and configuration |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guidelines and local development |
| [CHANGELOG.md](CHANGELOG.md) | Release history and notable changes |
| [TODO.md](TODO.md) | Future enhancements roadmap |
| [examples/argocd/README.md](examples/argocd/README.md) | ArgoCD deployment guide for GitOps |

## Project Structure

```
├── Dockerfile                 # Multi-stage, multi-arch Docker build
├── Makefile                   # Build, lint, and management commands
├── docker-compose.yml         # Local development orchestration
├── .env.example               # Environment template
├── .github/
│   ├── CODEOWNERS             # Code ownership rules
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml     # Bug report template
│   │   ├── feature_request.yml # Feature request template
│   │   └── config.yml         # Issue template chooser config
│   ├── pull_request_template.md # PR description template
│   ├── workflows/
│   │   ├── docker-build.yml   # Multi-arch image build + push
│   │   ├── helm-release.yml   # Helm chart packaging + OCI push
│   │   ├── security.yml       # Trivy vulnerability scanning
│   │   ├── smoke-test.yml     # Docker Compose stack smoke test
│   │   ├── validate-manifests.yml  # kubeconform validation
│   │   └── release.yml        # Version propagation automation
│   └── dependabot.yml         # Automated dependency updates
├── examples/
│   ├── default/               # Default variant
│   │   ├── docker/
│   │   ├── helm/
│   │   │   └── genieacs/templates/
│   │   │       ├── tests/     #   Helm chart tests (helm test)
│   │   │       ├── backup-cronjob.yaml  # Optional MongoDB backup CronJob
│   │   │       └── backup-pvc.yaml      # Backup PVC
│   │   └── kubernetes/        #   Kustomize manifests
│   ├── nbi-auth/              # NBI API auth variant
│   │   ├── docker/
│   │   ├── helm/
│   │   │   └── genieacs/templates/
│   │   │       ├── tests/     #   Helm chart tests (helm test)
│   │   │       ├── backup-cronjob.yaml  # Optional MongoDB backup CronJob
│   │   │       └── backup-pvc.yaml      # Backup PVC
│   │   └── kubernetes/        #   Kustomize manifests
│   └── argocd/                # ArgoCD application manifests
├── config/                    # supervisord configuration
├── scripts/                   # Utility scripts (create-user, run_with_env)
└── backups/                   # MongoDB backup archives
```

## Make Commands

```bash
make help          # Show all commands
make setup         # Initial setup (creates .env, validates secrets)
make up-d          # Start services (detached)
make create-user   # Create admin user from .env
make test          # Smoke-test all endpoints
make status        # Show container health
make logs          # Tail service logs
make backup        # Backup MongoDB (timestamped gzip)
make restore FILE= # Restore from backup
make down          # Stop services
make lint-docker   # Lint Dockerfile (Hadolint)
make lint-helm     # Lint Helm charts (--strict)
make helm-template # Render Helm templates to stdout
make buildx-load   # Build image for local arch
make scan          # CVE scan with Docker Scout
make stats         # Container resource usage

# Helm chart tests (run after install)
helm test genieacs -n genieacs
```

## Links

| Resource | URL |
|----------|-----|
| GitHub | https://github.com/Cepat-Kilat-Teknologi/genieacs-stack |
| Docker Hub | https://hub.docker.com/r/cepatkilatteknologi/genieacs |
| Helm Charts | https://cepat-kilat-teknologi.github.io/genieacs-stack |
| GenieACS | https://genieacs.com |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, code style, and PR guidelines.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Support

- **Email**: info@ckt.co.id
- **Issues**: [GitHub Issues](https://github.com/Cepat-Kilat-Teknologi/genieacs-stack/issues)