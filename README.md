# GenieACS Docker Deployment

![Docker](https://img.shields.io/badge/Docker-%E2%9C%93-blue?style=flat-square)
![MongoDB](https://img.shields.io/badge/MongoDB-8.0-green?style=flat-square)
![GenieACS](https://img.shields.io/badge/GenieACS-1.2.13-orange?style=flat-square)
![Node.js](https://img.shields.io/badge/Node.js-24-brightgreen?style=flat-square)
![Multi-Arch](https://img.shields.io/badge/multi--arch-amd64%2Carm64-lightgrey?style=flat-square)
[![ci](https://github.com/Cepat-Kilat-Teknologi/genieacs-docker/actions/workflows/docker-build.yml/badge.svg?branch=main)](https://github.com/Cepat-Kilat-Teknologi/genieacs-docker/actions/workflows/docker-build.yml)

Docker container for deployment GenieACS v1.2.13 with MongoDB 8.0, optimized for production use with security hardening, health checks, and log management.

## Features

- GenieACS v1.2.13 (CWMP, NBI, FS, UI)
- MongoDB 8.0 with health check
- Node.js 24 LTS
- Multi-architecture support (amd64, arm64)
- Security hardened image
- Auto-restart and health monitoring
- Log rotation support
- Data persistence with Docker volumes
- Environment variables configuration
- Backup and restore functionality
- Comprehensive management via Makefile

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Git
- Make (optional but recommended)
- curl (for health checks)

### Step 1: Clone Repository

```bash
git clone https://github.com/Cepat-Kilat-Teknologi/genieacs-docker.git
cd genieacs-docker
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

### Step 3: Setup & Build

```bash
# Create required directories
make setup

# Build Docker image
make build
```

### Step 4: Start Services

```bash
# Start all services
make up

# Wait for services to be healthy (about 30-60 seconds)
make status
```

### Step 5: Create Admin User

```bash
# Create admin user from .env credentials
make create-user
```

### Step 6: Access Web UI

Open http://localhost:3000 and login with credentials from your `.env` file:
- Username: value of `GENIEACS_ADMIN_USERNAME`
- Password: value of `GENIEACS_ADMIN_PASSWORD`

## Project Structure

```
.
├── Dockerfile              # Multi-stage Docker build (npm install)
├── Makefile                # Build and management commands
├── docker-compose.yml      # Service orchestration (development)
├── docker-compose.prod.yml # Production deployment (uses Docker Hub image)
├── .env.example            # Environment template (copy to .env)
├── .env.prod.example       # Production environment template
├── .env                    # Your local configuration (git ignored)
├── config/
│   ├── supervisord.conf    # Supervisor config for GenieACS services
│   └── genieacs.logrotate  # Log rotation config
├── scripts/
│   ├── create-user.sh      # User creation script
│   └── run_with_env.sh     # Service runner script
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

> **Note:** For Kubernetes deployment, NBI API authentication is handled via Nginx sidecar with X-API-Key header. See [NBI API Authentication](#nbi-api-authentication) section.

## Port Mapping

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| CWMP | 7547 | TCP | TR-069/CPE Management |
| NBI | 7557 | TCP | Northbound Interface API |
| FS | 7567 | TCP | File Server |
| UI | 3000 | TCP | Web Interface |

## Production Deployment

For production deployment using pre-built image from Docker Hub:

### Quick Production Setup

```bash
# 1. Download production files
curl -O https://raw.githubusercontent.com/Cepat-Kilat-Teknologi/genieacs-docker/main/docker-compose.prod.yml
curl -O https://raw.githubusercontent.com/Cepat-Kilat-Teknologi/genieacs-docker/main/.env.prod.example

# 2. Configure environment
cp .env.prod.example .env

# 3. Generate JWT secret and update .env
openssl rand -hex 32
# Edit .env and set GENIEACS_UI_JWT_SECRET and GENIEACS_ADMIN_PASSWORD

# 4. Start services
docker compose -f docker-compose.prod.yml up -d

# 5. Wait for services to be healthy (check status)
docker compose -f docker-compose.prod.yml ps

# 6. Create admin user
docker exec genieacs /bin/bash -c 'cd /opt/genieacs && node -e "
const crypto = require(\"crypto\");
const salt = crypto.randomBytes(16).toString(\"hex\");
const hash = crypto.createHash(\"sha256\").update(\"YOUR_PASSWORD\" + salt).digest(\"hex\");
console.log(JSON.stringify({_id:\"admin\",password:hash,salt:salt,roles:\"admin\"}));
"' | docker exec -i genieacs-mongo mongosh genieacs --eval 'db.users.insertOne(JSON.parse(require("fs").readFileSync("/dev/stdin","utf8")))'
```

### Production Features

- Pre-built multi-arch image (amd64, arm64)
- Resource limits (CPU, Memory)
- Log rotation with size limits
- Health checks with proper timeouts
- Security hardening enabled
- MongoDB not exposed to host

### Production Compose Commands

```bash
# Start services
docker compose -f docker-compose.prod.yml up -d

# View logs
docker compose -f docker-compose.prod.yml logs -f

# Stop services
docker compose -f docker-compose.prod.yml down

# Update to latest image
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

## Kubernetes Deployment

For Kubernetes deployment, use the manifests in the `k8s/` directory.

### Prerequisites

- Kubernetes cluster (v1.25+)
- kubectl configured
- Nginx Ingress Controller (optional, for ingress)
- Longhorn or other storage provisioner

### Quick Kubernetes Setup

```bash
# 1. Apply all manifests
kubectl apply -k k8s/

# 2. Wait for pods to be ready
kubectl get pods -n genieacs -w

# 3. Access services via LoadBalancer IP
kubectl get svc -n genieacs
```

### Kubernetes Files

| File | Description |
|------|-------------|
| `namespace.yaml` | GenieACS namespace |
| `configmap.yaml` | Environment configuration |
| `secret.yaml` | Sensitive data (JWT secret) |
| `nginx-nbi-auth.yaml` | NBI API authentication (Nginx sidecar) |
| `mongodb-*.yaml` | MongoDB deployment, service, PVC |
| `genieacs-*.yaml` | GenieACS deployment, service, PVC |
| `ingress.yaml` | Ingress rules (optional) |
| `kustomization.yaml` | Kustomize configuration |

### NBI API Authentication

The NBI API is secured using X-API-Key header authentication via Nginx sidecar.

**Configuration:** Edit `k8s/nginx-nbi-auth.yaml` to change the API key:

```nginx
if ($http_x_api_key != "your-api-key-here") {
    return 401 "Invalid or missing X-API-Key";
}
```

**Usage:**

```bash
# Without API key - returns 401
curl http://<LOADBALANCER_IP>:7557/devices

# With API key - returns 200
curl -H "X-API-Key: your-api-key-here" http://<LOADBALANCER_IP>:7557/devices

# Example: Get all devices
curl -H "X-API-Key: your-api-key-here" http://<LOADBALANCER_IP>:7557/devices | jq

# Example: Get presets
curl -H "X-API-Key: your-api-key-here" http://<LOADBALANCER_IP>:7557/presets | jq

# Example: Create/update preset
curl -X PUT \
  -H "X-API-Key: your-api-key-here" \
  -H "Content-Type: application/json" \
  -d '{"weight":0,"channel":"default","events":"Registered"}' \
  http://<LOADBALANCER_IP>:7557/presets/my-preset
```

**Generate new API key:**

```bash
# Generate random 32-byte hex key
openssl rand -hex 32
```

### Kubernetes Management Commands

```bash
# View all resources
kubectl get all -n genieacs

# View logs
kubectl logs -f deployment/genieacs -n genieacs

# Restart deployment
kubectl rollout restart deployment/genieacs -n genieacs

# Scale deployment
kubectl scale deployment/genieacs --replicas=2 -n genieacs

# Access MongoDB shell
kubectl exec -it deployment/mongodb -n genieacs -- mongosh genieacs

# Access GenieACS shell
kubectl exec -it deployment/genieacs -n genieacs -- /bin/bash
```

## Management Commands

### Build & Deployment

```bash
make setup        # Create required directories and config files
make build        # Build image for current architecture
make buildx       # Build multi-platform image
make buildx-push  # Build and push multi-platform image
make push         # Push image to registry
```

### Service Management

```bash
make up           # Start services in background
make down         # Stop and remove services
make stop         # Stop services (keep containers)
make restart      # Restart services
make logs         # View real-time logs
```

### User Management

```bash
make create-user  # Create admin user from .env credentials

# Or manually with custom credentials:
./scripts/create-user.sh myuser mypassword admin
```

### Monitoring & Status

```bash
make status       # Check service status and health
make ps           # Show running containers
make test         # Test all service endpoints
make stats        # Show container resource usage
```

### Database Operations

```bash
make shell-mongo     # Access MongoDB shell
make shell-genieacs  # Access GenieACS container shell
make backup          # Backup MongoDB database
make restore FILE=backups/backup_20240101_120000.gz  # Restore backup
```

### Maintenance

```bash
make clean        # Stop services and remove images
make prune        # Prune unused Docker resources
make scan         # Scan image for vulnerabilities
make verify-deps  # Verify dependency versions
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
- X-API-Key authentication for NBI API (Kubernetes)
- No default credentials (must be configured via `.env`)
- MongoDB not exposed to host by default
- `no-new-privileges` security option enabled
- Non-root process execution where possible
- Minimal base image (debian:bookworm-slim)
- Configurable port bindings
- Environment variables for sensitive data

### Security Checklist for Production

- [ ] Generate unique `GENIEACS_UI_JWT_SECRET` using `openssl rand -hex 32`
- [ ] Set strong `GENIEACS_ADMIN_PASSWORD`
- [ ] Enable `GENIEACS_UI_AUTH=true`
- [ ] Configure NBI API key in `k8s/nginx-nbi-auth.yaml` (Kubernetes)
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
# Test MongoDB
docker exec mongo-genieacs mongosh --eval "db.adminCommand('ping')"

# Test GenieACS UI
curl -f http://localhost:3000/

# Test GenieACS CWMP
curl -f http://localhost:7547/

# Test GenieACS NBI (Docker Compose)
curl -f http://localhost:7557/

# Test GenieACS NBI (Kubernetes - requires X-API-Key)
curl -H "X-API-Key: your-api-key" http://<LOADBALANCER_IP>:7557/devices
```

## Troubleshooting

### Cannot Login to Web UI

```bash
# Ensure services are running and healthy
make status

# Create/recreate admin user
make create-user

# Check if user exists in MongoDB
docker exec mongo-genieacs mongosh genieacs --eval "db.users.find()"
```

### Port Already in Use

```bash
# Check which process is using the port
sudo lsof -i :3000
sudo lsof -i :7547

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

### Build Failures

```bash
# Clean and rebuild
make clean
make build

# Check Docker disk space
docker system df
make prune
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
docker exec genieacs cat /var/log/genieacs/cwmp-access.log
```

## Docker Images

- **Base Image**: `debian:bookworm-slim`
- **Node.js**: 24 LTS (Krypton)
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
- **Issues**: [GitHub Issues](https://github.com/Cepat-Kilat-Teknologi/genieacs-docker/issues)

---

**Important**: Always test in a staging environment before production deployment. Ensure regular backups of your MongoDB data.