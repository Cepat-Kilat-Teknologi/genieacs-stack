# GenieACS Stack

![Docker](https://img.shields.io/badge/Docker-%E2%9C%93-blue?style=flat-square)
![Kubernetes](https://img.shields.io/badge/Kubernetes-%E2%9C%93-326CE5?style=flat-square)
![Helm](https://img.shields.io/badge/Helm-%E2%9C%93-0F1689?style=flat-square)
![MongoDB](https://img.shields.io/badge/MongoDB-8.0-green?style=flat-square)
![GenieACS](https://img.shields.io/badge/GenieACS-1.2.13-orange?style=flat-square)
![Node.js](https://img.shields.io/badge/Node.js-24-brightgreen?style=flat-square)
![Multi-Arch](https://img.shields.io/badge/multi--arch-amd64%2Carm64-lightgrey?style=flat-square)
[![ci](https://github.com/Cepat-Kilat-Teknologi/genieacs-stack/actions/workflows/docker-build.yml/badge.svg?branch=main)](https://github.com/Cepat-Kilat-Teknologi/genieacs-stack/actions/workflows/docker-build.yml)

Complete deployment stack for GenieACS v1.2.13 with MongoDB 8.0. Supports Docker Compose, Kubernetes (Kustomize), and Helm deployments. Production-ready with security hardening, health checks, and optional NBI API authentication.

## Features

- **GenieACS v1.2.13** - CWMP, NBI, FS, UI services
- **MongoDB 8.0** - Database with health checks
- **Multi-platform Deployment**:
  - Docker Compose (development & production)
  - Kubernetes with Kustomize
  - Helm Charts
- **NBI API Authentication** - Optional X-API-Key protection via Nginx proxy
- **Multi-architecture** - amd64, arm64 support
- **Production Ready**:
  - Security hardened images
  - Health monitoring & auto-restart
  - Log rotation
  - Data persistence
  - Backup & restore functionality

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Git
- Make (optional but recommended)
- curl (for health checks)

### Step 1: Clone Repository

```bash
git clone https://github.com/Cepat-Kilat-Teknologi/genieacs-stack.git
cd genieacs-stack
```

### Step 2: Configure Environment

```bash
# Copy example environment file
cp .env.example .env

# Generate secure JWT secret
openssl rand -hex 32

# Edit .env and update these values:
# - GENIEACS_UI_JWT_SECRET (paste the generated secret)
# - GENIEACS_ADMIN_USERNAME
# - GENIEACS_ADMIN_PASSWORD
```

### Step 3: Setup & Start

```bash
# Create required directories
make setup

# Start services (background)
make up-d

# Wait for services to be healthy
make status
```

### Step 4: Create Admin User

```bash
# Create admin user from .env credentials
make create-user
```

### Step 5: Access Web UI

Open http://localhost:3000 and login with credentials from your `.env` file:
- Username: value of `GENIEACS_ADMIN_USERNAME`
- Password: value of `GENIEACS_ADMIN_PASSWORD`

### Step 6: Verify Services

```bash
# Test all endpoints
make test
```

## Project Structure

```
.
├── Dockerfile              # Multi-stage Docker build
├── Makefile                # Build and management commands
├── docker-compose.yml      # Service orchestration
├── .env.example            # Environment template (copy to .env)
├── config/
│   ├── supervisord.conf    # Supervisor config for GenieACS services
│   └── genieacs.logrotate  # Log rotation config
├── scripts/
│   ├── create-user.sh      # User creation script (PBKDF2-SHA512)
│   └── run_with_env.sh     # Service runner script
├── examples/
│   ├── default/            # Basic deployment examples
│   │   ├── docker/         # Docker Compose (production-ready)
│   │   ├── kubernetes/     # Kubernetes manifests (Kustomize)
│   │   └── helm/           # Helm chart
│   └── nbi-auth/           # NBI API authentication examples
│       ├── docker/         # Docker with Nginx proxy
│       ├── kubernetes/     # Kubernetes with Nginx sidecar
│       └── helm/           # Helm chart with NBI auth
├── ext/                    # GenieACS extensions directory
└── backups/                # MongoDB backups directory
```

## Environment Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `GENIEACS_UI_JWT_SECRET` | JWT secret for authentication (min 32 chars) | `openssl rand -hex 32` |
| `GENIEACS_ADMIN_USERNAME` | Admin username for GUI | `admin` |
| `GENIEACS_ADMIN_PASSWORD` | Admin password for GUI | `your-secure-password` |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GENIEACS_UI_AUTH` | `true` | Enable UI authentication |
| `GENIEACS_CWMP_PORT` | `7547` | CWMP service port |
| `GENIEACS_NBI_PORT` | `7557` | NBI API port |
| `GENIEACS_FS_PORT` | `7567` | File server port |
| `GENIEACS_UI_PORT` | `3000` | Web UI port |

> **Note:** For NBI API authentication with X-API-Key, see `examples/nbi-auth/`.

## Port Mapping

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| CWMP | 7547 | TCP | TR-069/CPE Management |
| NBI | 7557 | TCP | Northbound Interface API |
| FS | 7567 | TCP | File Server |
| UI | 3000 | TCP | Web Interface |

## Deployment Examples

### Docker Compose (Production)

For production deployment with pre-built images:

```bash
cd examples/default/docker
cp .env.example .env
# Edit .env with your settings
docker compose up -d
```

See `examples/default/docker/README.md` for details.

### Kubernetes (Kustomize)

For Kubernetes deployment using Kustomize:

```bash
cd examples/default/kubernetes
# Edit secret.yaml and configmap.yaml
kubectl apply -k .
```

See `examples/default/kubernetes/README.md` for details.

### Helm

For Kubernetes deployment using Helm:

```bash
# Install from local chart
helm install genieacs ./examples/default/helm/genieacs \
  --create-namespace \
  --namespace genieacs

# Or with custom values
helm install genieacs ./examples/default/helm/genieacs \
  --namespace genieacs \
  --set secret.jwtSecret="$(openssl rand -hex 32)"
```

See `examples/default/helm/README.md` for details.

### NBI API Authentication

GenieACS NBI API does not have native authentication. For secured NBI access:

- **Docker**: See `examples/nbi-auth/docker/`
- **Kubernetes**: See `examples/nbi-auth/kubernetes/`
- **Helm**: See `examples/nbi-auth/helm/`

These examples use Nginx as a reverse proxy with X-API-Key header authentication.

## Management Commands

### Quick Reference

```bash
make help         # Show all commands
make setup        # Create directories and .env
make up-d         # Start services (background)
make create-user  # Create admin user
make test         # Test all endpoints
make status       # Check health status
make logs         # View logs
make down         # Stop services
```

### Build & Deployment

```bash
make build        # Build Docker image
make buildx       # Build multi-platform image
make buildx-push  # Build and push to registry
```

### Service Management

```bash
make up           # Start services (foreground)
make up-d         # Start services (background)
make down         # Stop and remove services
make stop         # Stop services (keep containers)
make restart      # Restart services
make logs         # View real-time logs
make status       # Check service status and health
make ps           # Show running containers
make stats        # Show resource usage
```

### User Management

```bash
make create-user  # Create admin user from .env credentials

# Or manually with custom credentials:
./scripts/create-user.sh myuser mypassword admin
```

### Database Operations

```bash
make shell-mongo  # Access MongoDB shell
make backup       # Backup MongoDB database
make restore FILE=backups/backup_20240101_120000.gz  # Restore backup
```

### Maintenance

```bash
make clean        # Stop services and remove volumes
make fresh        # Clean and start fresh
make prune        # Prune unused Docker resources
make scan         # Scan image for vulnerabilities
```

## Volumes & Data Persistence

| Volume | Description | Container Path |
|--------|-------------|----------------|
| `genieacs-mongo-data` | MongoDB data storage | `/data/db` |
| `genieacs-mongo-configdb` | MongoDB config storage | `/data/configdb` |
| `genieacs-app-data` | GenieACS application data | `/opt/genieacs` |
| `genieacs-logs` | Application logs | `/var/log/genieacs` |

## Security Features

- JWT-based authentication for UI
- No default credentials (must be configured via `.env`)
- MongoDB not exposed to host by default
- `no-new-privileges` security option enabled
- Non-root process execution where possible
- Minimal base image (debian:bookworm-slim)
- Configurable port bindings
- Environment variables for sensitive data
- Optional NBI API authentication (see `examples/nbi-auth/`)

### Security Checklist for Production

- [ ] Generate unique `GENIEACS_UI_JWT_SECRET` using `openssl rand -hex 32`
- [ ] Set strong `GENIEACS_ADMIN_PASSWORD`
- [ ] Enable `GENIEACS_UI_AUTH=true`
- [ ] Enable NBI API authentication (see `examples/nbi-auth/`)
- [ ] Consider binding ports to `127.0.0.1` if behind reverse proxy
- [ ] Regular backups using `make backup`
- [ ] Keep Docker images updated

## Health Checks

Both containers include automated health checks:

| Container | Check | Interval | Start Period |
|-----------|-------|----------|--------------|
| MongoDB | `mongosh ping` | 10s | 20s |
| GenieACS | `curl localhost:3000` | 30s | 60s |

### Manual Health Testing

```bash
# Test all services
make test

# Or manually:
docker exec mongo-genieacs mongosh --eval "db.adminCommand('ping')"
curl -f http://localhost:3000/
curl http://localhost:7557/devices
```

## Troubleshooting

### Cannot Login to Web UI

```bash
# Ensure services are running and healthy
make status

# Create/recreate admin user
make create-user

# Check if user exists in MongoDB
docker exec mongo-genieacs mongosh genieacs --eval "db.users.find({}, {_id:1, roles:1})"
```

### Port Already in Use

```bash
# Check which process is using the port
lsof -i :3000
lsof -i :7547

# Use alternative ports in .env
GENIEACS_UI_PORT=3001
GENIEACS_CWMP_PORT=7548
```

### MongoDB Connection Issues

```bash
# Check MongoDB logs
docker logs mongo-genieacs

# Check MongoDB health
docker exec mongo-genieacs mongosh --eval "db.adminCommand('ping')"

# Restart services
make restart
```

### View Logs

```bash
# All services
make logs

# Specific container
docker logs genieacs -f
docker logs mongo-genieacs -f

# GenieACS internal logs
docker exec genieacs ls -la /var/log/genieacs/
```

## Docker Images

- **Base Image**: `debian:bookworm-slim`
- **Node.js**: 24 LTS
- **MongoDB**: 8.0
- **Image Tags**:
  - `cepatkilatteknologi/genieacs:v1.2.13`
  - `cepatkilatteknologi/genieacs:latest`

## Contributing

1. Fork the project
2. Create your feature branch (`git checkout -b feature/YourFeature`)
3. Commit your changes (`git commit -m 'Add YourFeature'`)
4. Push to the branch (`git push origin feature/YourFeature`)
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [GenieACS](https://github.com/genieacs/genieacs) - Open source TR-069 ACS
- [Docker](https://www.docker.com/) - Container platform
- [MongoDB](https://www.mongodb.com/) - Database solution

## Support

- **Email**: info@ckt.co.id
- **Issues**: [GitHub Issues](https://github.com/Cepat-Kilat-Teknologi/genieacs-stack/issues)

---

**Important**: Always test in a staging environment before production deployment. Ensure regular backups of your MongoDB data.