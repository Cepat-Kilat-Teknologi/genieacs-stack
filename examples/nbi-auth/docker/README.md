# GenieACS Docker Compose - NBI API Authentication

Docker Compose deployment for GenieACS with X-API-Key authentication for NBI API.

> For deployment without NBI API authentication, see: `examples/default/docker/`

## Prerequisites

- Docker Engine 20.10+
- Docker Compose v2+
- Minimum 2GB RAM
- 10GB disk space

## Quick Start

### 1. Navigate to Directory

```bash
cd examples/nbi-auth/docker
```

### 2. Configure Environment

```bash
# Copy template
cp .env.example .env

# Generate JWT secret
openssl rand -hex 32
# Paste to GENIEACS_UI_JWT_SECRET in .env

# Generate NBI API key
openssl rand -hex 32
# Paste to GENIEACS_NBI_API_KEY in .env

# Edit file
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
| NBI API | http://localhost:7557 | With X-API-Key auth |
| File Server | http://localhost:7567 | Firmware upload |

## NBI API Authentication

NBI API on port 7557 requires `X-API-Key` header:

```bash
# Without API key - returns 401
curl http://localhost:7557/devices
# {"error": "Invalid or missing X-API-Key"}

# With API key - returns 200
curl -H "X-API-Key: your-api-key" http://localhost:7557/devices

# Health check (no auth required)
curl http://localhost:7557/health
```

### Usage Examples

```bash
# Set API key as variable
export API_KEY="your-api-key-here"

# Get all devices
curl -H "X-API-Key: $API_KEY" http://localhost:7557/devices

# Get presets
curl -H "X-API-Key: $API_KEY" http://localhost:7557/presets

# Get device by ID
curl -H "X-API-Key: $API_KEY" \
  "http://localhost:7557/devices?query=%7B%22_id%22%3A%22device-001%22%7D"

# Create preset
curl -X PUT \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"weight":0,"channel":"default","events":"Registered"}' \
  http://localhost:7557/presets/my-preset

# Trigger task on device
curl -X POST \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"getParameterValues","parameterNames":["Device.DeviceInfo."]}' \
  "http://localhost:7557/devices/device-001/tasks"
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GENIEACS_UI_JWT_SECRET` | JWT secret (required) | - |
| `GENIEACS_NBI_API_KEY` | NBI API key (required) | - |
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

## Architecture

```
                    ┌─────────────────┐
                    │   Client/App    │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
         ┌────────┐    ┌─────────┐    ┌─────────┐
         │ UI:3000│    │NBI:7557 │    │CWMP:7547│
         └────┬───┘    └────┬────┘    └────┬────┘
              │             │              │
              │        ┌────▼────┐         │
              │        │  Nginx  │         │
              │        │(API Key)│         │
              │        └────┬────┘         │
              │             │              │
              └──────┬──────┴──────────────┘
                     │
                ┌────▼────┐
                │GenieACS │
                └────┬────┘
                     │
                ┌────▼────┐
                │ MongoDB │
                └─────────┘
```

## Docker Commands

### View Logs

```bash
# All services
docker compose logs -f

# Per service
docker compose logs -f genieacs
docker compose logs -f nbi-proxy
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
docker compose restart nbi-proxy

# Update image and restart
docker compose pull && docker compose up -d
```

### Access Containers

```bash
# GenieACS container
docker exec -it genieacs /bin/bash

# MongoDB container
docker exec -it mongo-genieacs mongosh

# NBI Proxy container
docker exec -it genieacs-nbi-proxy sh
```

## Volumes

| Volume | Description |
|--------|-------------|
| `mongo-genieacs-data` | MongoDB data |
| `mongo-genieacs-configdb` | MongoDB config |
| `genieacs-app-data` | GenieACS application data |
| `genieacs-logs` | GenieACS log files |
| `genieacs-ext` | GenieACS extensions |

## File Structure

```
docker/
├── .env.example              # Environment template
├── .env                      # Environment variables (created by user)
├── docker-compose.yml        # Docker Compose configuration
├── config/
│   └── nginx/
│       ├── nbi-proxy.conf.template  # Nginx config template
│       └── docker-entrypoint.sh     # Nginx entrypoint script
└── README.md                 # Documentation
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

## Security Features

- NBI API protected with X-API-Key authentication
- Internal NBI port (7557) not exposed to host, only through proxy
- Health check endpoint `/health` available without authentication
- Nginx runs as non-root process
- Security options: `no-new-privileges:true`

## Troubleshooting

### NBI returns 401

Ensure `X-API-Key` header matches value in `.env`:

```bash
# Check API key
cat .env | grep GENIEACS_NBI_API_KEY

# Test with API key
curl -H "X-API-Key: $(grep GENIEACS_NBI_API_KEY .env | cut -d= -f2)" \
  http://localhost:7557/devices
```

### Container won't start

```bash
# Check logs
docker compose logs nbi-proxy
docker compose logs genieacs

# Check events
docker compose events
```

### NBI Proxy error

```bash
# Check nginx config
docker exec genieacs-nbi-proxy cat /etc/nginx/nginx.conf

# Check nginx logs
docker compose logs nbi-proxy
```

### Regenerate API Key

```bash
# Generate new key
NEW_KEY=$(openssl rand -hex 32)
echo "New API Key: $NEW_KEY"

# Update .env
sed -i '' "s/GENIEACS_NBI_API_KEY=.*/GENIEACS_NBI_API_KEY=$NEW_KEY/" .env

# Restart nbi-proxy
docker compose restart nbi-proxy
```

### Port conflict

Change port in `.env`:

```bash
GENIEACS_UI_PORT=3001
GENIEACS_NBI_PORT=7558
```

## Resource Limits

Default resource limits in `docker-compose.yml`:

| Service | CPU Limit | Memory Limit |
|---------|-----------|--------------|
| MongoDB | 2 cores | 2GB |
| GenieACS | 2 cores | 1GB |
| NBI Proxy | 0.5 cores | 128MB |