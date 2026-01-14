# GenieACS Docker Deployment

![Docker](https://img.shields.io/badge/Docker-%E2%9C%93-blue?style=flat-square)
![MongoDB](https://img.shields.io/badge/MongoDB-8.0-green?style=flat-square)
![GenieACS](https://img.shields.io/badge/GenieACS-1.2.13-orange?style=flat-square)
![Node.js](https://img.shields.io/badge/Node.js-24-brightgreen?style=flat-square)
![Multi-Arch](https://img.shields.io/badge/multi--arch-amd64%2Carm64%2Carmv7-lightgrey?style=flat-square)
[![ci](https://github.com/Cepat-Kilat-Teknologi/genieacs-docker/actions/workflows/docker-build.yml/badge.svg?branch=main)](https://github.com/Cepat-Kilat-Teknologi/genieacs-docker/actions/workflows/docker-build.yml)

Docker container for deployment GenieACS v1.2.13 with MongoDB 8.0, optimized for production use with security hardening, health checks, and log management.

## Features

- GenieACS v1.2.13 (CWMP, NBI, FS, UI)
- MongoDB 8.0 with health check
- Node.js 24 LTS
- Multi-architecture support (amd64, arm64, arm/v7)
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
├── docker-compose.yml      # Service orchestration
├── .env.example            # Environment template (copy to .env)
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
| `GENIEACS_NBI_AUTH` | `true` | Enable NBI API authentication |
| `GENIEACS_UI_AUTH` | `true` | Enable UI authentication |
| `GENIEACS_CWMP_PORT` | `7547` | CWMP service port |
| `GENIEACS_NBI_PORT` | `7557` | NBI API port |
| `GENIEACS_FS_PORT` | `7567` | File server port |
| `GENIEACS_UI_PORT` | `3000` | Web UI port |

## Port Mapping

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| CWMP | 7547 | TCP | TR-069/CPE Management |
| NBI | 7557 | TCP | Northbound Interface API |
| FS | 7567 | TCP | File Server |
| UI | 3000 | TCP | Web Interface |

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

- JWT-based authentication for UI and NBI API
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
- [ ] Enable `GENIEACS_NBI_AUTH=true`
- [ ] Enable `GENIEACS_UI_AUTH=true`
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

# Test GenieACS NBI
curl -f http://localhost:7557/
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