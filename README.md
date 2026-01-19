# GenieACS Stack

[![ci](https://github.com/Cepat-Kilat-Teknologi/genieacs-stack/actions/workflows/docker-build.yml/badge.svg?branch=main)](https://github.com/Cepat-Kilat-Teknologi/genieacs-stack/actions/workflows/docker-build.yml)
[![Helm](https://github.com/Cepat-Kilat-Teknologi/genieacs-stack/actions/workflows/helm-release.yml/badge.svg)](https://github.com/Cepat-Kilat-Teknologi/genieacs-stack/actions/workflows/helm-release.yml)
![GenieACS](https://img.shields.io/badge/GenieACS-1.2.13-orange?style=flat-square)
![MongoDB](https://img.shields.io/badge/MongoDB-8.0-green?style=flat-square)
![Multi-Arch](https://img.shields.io/badge/multi--arch-amd64%2Carm64-lightgrey?style=flat-square)

Complete deployment stack for [GenieACS](https://genieacs.com) v1.2.13 with MongoDB 8.0. Supports Docker Compose, Kubernetes, and Helm deployments with optional NBI API authentication.

## Features

- **GenieACS v1.2.13** - CWMP, NBI, FS, UI services
- **MongoDB 8.0** - Database with health checks
- **Multiple Deployment Options** - Docker Compose, Kubernetes (Kustomize), Helm Charts
- **NBI API Authentication** - Optional X-API-Key protection via Nginx proxy
- **Multi-architecture** - amd64, arm64 support
- **Production Ready** - Security hardened, health monitoring, log rotation, data persistence

## Quick Start

### Using Docker Compose

```bash
git clone https://github.com/Cepat-Kilat-Teknologi/genieacs-stack.git
cd genieacs-stack

cp .env.example .env
# Edit .env and set GENIEACS_UI_JWT_SECRET (use: openssl rand -hex 32)

make setup && make up-d
make create-user
```

Access: http://localhost:3000

### Using Helm

```bash
# Add repository
helm repo add genieacs https://cepat-kilat-teknologi.github.io/genieacs-stack
helm repo update

# Install
helm install genieacs genieacs/genieacs \
  --namespace genieacs \
  --create-namespace \
  --set secret.jwtSecret="$(openssl rand -hex 32)"
```

### Using Kubernetes (Kustomize)

```bash
cd examples/default/kubernetes
# Edit secret.yaml with your JWT secret
kubectl apply -k .
```

> **Full installation guide**: See [INSTALLATION.md](INSTALLATION.md)

## Available Deployments

| Type | Default | With NBI Auth | Description |
|------|---------|---------------|-------------|
| Docker | `examples/default/docker/` | `examples/nbi-auth/docker/` | Docker Compose |
| Kubernetes | `examples/default/kubernetes/` | `examples/nbi-auth/kubernetes/` | Kustomize manifests |
| Helm | `genieacs/genieacs` | `genieacs/genieacs-nbi-auth` | Helm charts |

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
| [examples/argocd/README.md](examples/argocd/README.md) | ArgoCD deployment guide for GitOps |

## Project Structure

```
├── Dockerfile                 # Multi-stage Docker build
├── Makefile                   # Build and management commands
├── docker-compose.yml         # Service orchestration
├── .env.example               # Environment template
├── examples/
│   ├── default/               # Basic deployments
│   │   ├── docker/
│   │   ├── kubernetes/
│   │   └── helm/
│   ├── nbi-auth/              # With NBI API authentication
│   │   ├── docker/
│   │   ├── kubernetes/
│   │   └── helm/
│   └── argocd/                # ArgoCD application manifests
├── config/                    # Configuration files
├── scripts/                   # Utility scripts
└── backups/                   # MongoDB backups
```

## Make Commands

```bash
make help         # Show all commands
make setup        # Initial setup
make up-d         # Start services
make create-user  # Create admin user
make test         # Test endpoints
make status       # Check health
make logs         # View logs
make backup       # Backup MongoDB
make down         # Stop services
```

## Links

| Resource | URL |
|----------|-----|
| GitHub | https://github.com/Cepat-Kilat-Teknologi/genieacs-stack |
| Docker Hub | https://hub.docker.com/r/cepatkilatteknologi/genieacs |
| Helm Charts | https://cepat-kilat-teknologi.github.io/genieacs-stack |
| GenieACS | https://genieacs.com |

## Contributing

1. Fork the project
2. Create your feature branch (`git checkout -b feature/YourFeature`)
3. Commit your changes (`git commit -m 'Add YourFeature'`)
4. Push to the branch (`git push origin feature/YourFeature`)
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Email**: info@ckt.co.id
- **Issues**: [GitHub Issues](https://github.com/Cepat-Kilat-Teknologi/genieacs-stack/issues)