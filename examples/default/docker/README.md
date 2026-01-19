# GenieACS Docker Compose - Default Deployment

Docker Compose deployment for GenieACS (without NBI API authentication).

> For deployment with NBI API authentication, see: `examples/nbi-auth/docker/`

## Prerequisites

- Docker Engine 20.10+
- Docker Compose v2+
- Minimum 2GB RAM
- 10GB disk space

## Quick Start

### 1. Navigate to Directory

```bash
cd examples/default/docker
```

### 2. Configure Environment

```bash
# Copy template
cp .env.example .env

# Generate JWT secret
openssl rand -hex 32

# Edit .env and paste JWT secret
nano .env
```

### 3. Start GenieACS

```bash
docker compose up -d
```

### 4. Verify Deployment

```bash
# Check container status
docker compose ps

# Wait until healthy (~90 seconds)
docker compose logs -f genieacs
```

### 5. Create Admin User

Wait for containers to be healthy, then run from project root:

```bash
cd ../../..
./scripts/create-user.sh admin yourpassword admin
```

### 6. Access GenieACS

| Service | URL | Description |
|---------|-----|-------------|
| Web UI | http://localhost:3000 | Management interface |
| CWMP | http://localhost:7547 | TR-069 for CPE devices |
| NBI API | http://localhost:7557 | Northbound API |
| File Server | http://localhost:7567 | Firmware upload |

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GENIEACS_UI_JWT_SECRET` | JWT secret (required) | - |
| `GENIEACS_UI_AUTH` | Enable UI authentication | `true` |
| `GENIEACS_CWMP_PORT` | CWMP port | `7547` |
| `GENIEACS_NBI_PORT` | NBI API port | `7557` |
| `GENIEACS_FS_PORT` | File Server port | `7567` |
| `GENIEACS_UI_PORT` | Web UI port | `3000` |

### Custom Ports

Edit `.env` to change ports:

```bash
GENIEACS_UI_PORT=3001
GENIEACS_CWMP_PORT=7548
GENIEACS_NBI_PORT=7558
GENIEACS_FS_PORT=7568
```

## Docker Commands

### View Logs

```bash
# All services
docker compose logs -f

# GenieACS only
docker compose logs -f genieacs

# MongoDB only
docker compose logs -f mongo
```

### Management

```bash
# Container status
docker compose ps

# Stop services
docker compose down

# Restart services
docker compose restart

# Restart single service
docker compose restart genieacs

# Update image and restart
docker compose pull && docker compose up -d
```

### Access Containers

```bash
# GenieACS container
docker exec -it genieacs /bin/bash

# MongoDB container
docker exec -it mongo-genieacs mongosh
```

## Volumes

| Volume | Description |
|--------|-------------|
| `mongo-genieacs-data` | MongoDB data |
| `mongo-genieacs-configdb` | MongoDB config |
| `genieacs-app-data` | GenieACS application data |
| `genieacs-logs` | GenieACS log files |
| `genieacs-ext` | GenieACS extensions |

### View Volumes

```bash
docker volume ls | grep genieacs
```

## Backup & Restore

### Backup Database

```bash
# Backup MongoDB
docker exec mongo-genieacs mongodump --out /data/db/backup

# Copy to host
docker cp mongo-genieacs:/data/db/backup ./backup
```

### Restore Database

```bash
# Copy backup to container
docker cp ./backup mongo-genieacs:/data/db/backup

# Restore
docker exec mongo-genieacs mongorestore /data/db/backup
```

### Backup Volumes

```bash
# Backup all volumes
docker run --rm \
  -v mongo-genieacs-data:/data \
  -v $(pwd):/backup \
  busybox tar czf /backup/mongo-data.tar.gz /data
```

## File Structure

```
docker/
├── .env.example        # Environment template
├── .env                # Environment variables (created by user)
├── docker-compose.yml  # Docker Compose configuration
└── README.md           # Documentation
```

## Resource Limits

Default resource limits in `docker-compose.yml`:

| Service | CPU Limit | Memory Limit |
|---------|-----------|--------------|
| MongoDB | 2 cores | 2GB |
| GenieACS | 2 cores | 1GB |

## Troubleshooting

### Container won't start

```bash
# Check logs
docker compose logs genieacs

# Check events
docker compose events
```

### MongoDB error

```bash
# Check MongoDB status
docker compose ps mongo

# Check MongoDB logs
docker compose logs mongo

# Test connection
docker exec mongo-genieacs mongosh --eval "db.adminCommand('ping')"
```

### Port conflict

Change port in `.env`:

```bash
GENIEACS_UI_PORT=3001
GENIEACS_CWMP_PORT=7548
```

### Permission denied

```bash
# Reset permissions
docker compose down
docker volume rm genieacs-logs genieacs-ext
docker compose up -d
```

### Out of memory

Increase memory limit in `docker-compose.yml` or system.

## Security Notes

- NBI API on port 7557 **has no authentication**
- For NBI API authentication, use: `examples/nbi-auth/docker/`
- Or bind to localhost only: `GENIEACS_NBI_PORT=127.0.0.1:7557`
- Always use a strong JWT secret in production