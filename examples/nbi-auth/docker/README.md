# GenieACS Docker - NBI API Authentication

Deployment GenieACS dengan X-API-Key authentication untuk NBI API.

## Prerequisites

- Docker Engine 20.10+
- Docker Compose v2+
- Minimal 2GB RAM
- 10GB disk space

## Quick Start

### 1. Masuk ke direktori

```bash
cd examples/nbi-auth/docker
```

### 2. Konfigurasi Environment

```bash
# Copy template
cp .env.example .env

# Generate JWT secret
openssl rand -hex 32
# Paste ke GENIEACS_UI_JWT_SECRET di .env

# Generate NBI API key
openssl rand -hex 32
# Paste ke GENIEACS_NBI_API_KEY di .env
```

### 3. Jalankan GenieACS

```bash
docker compose up -d
```

### 4. Buat Admin User

Tunggu container healthy (~60 detik), lalu jalankan dari root project:

```bash
cd ../../..
./scripts/create-user.sh admin yourpassword admin
```

### 5. Akses GenieACS

| Service | URL | Deskripsi |
|---------|-----|-----------|
| Web UI | http://localhost:3000 | Interface manajemen |
| CWMP | http://localhost:7547 | TR-069 untuk CPE |
| NBI API | http://localhost:7557 | Dengan X-API-Key auth |
| File Server | http://localhost:7567 | Firmware upload |

## NBI API Authentication

NBI API pada port 7557 memerlukan header `X-API-Key`:

```bash
# Tanpa API key - return 401
curl http://localhost:7557/devices
# {"error": "Invalid or missing X-API-Key"}

# Dengan API key - return 200
curl -H "X-API-Key: your-api-key" http://localhost:7557/devices
```

### Contoh Penggunaan

```bash
# Get semua devices
curl -H "X-API-Key: your-api-key" http://localhost:7557/devices | jq

# Get presets
curl -H "X-API-Key: your-api-key" http://localhost:7557/presets | jq

# Get device by ID
curl -H "X-API-Key: your-api-key" \
  "http://localhost:7557/devices?query=%7B%22_id%22%3A%22device-001%22%7D" | jq

# Create preset
curl -X PUT \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{"weight":0,"channel":"default","events":"Registered"}' \
  http://localhost:7557/presets/my-preset

# Trigger task pada device
curl -X POST \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{"name":"getParameterValues","parameterNames":["Device.DeviceInfo."]}' \
  "http://localhost:7557/devices/device-001/tasks"
```

## Perintah Berguna

```bash
# Melihat logs
docker compose logs -f

# Logs per service
docker compose logs -f genieacs
docker compose logs -f nbi-proxy

# Status containers
docker compose ps

# Stop services
docker compose down

# Restart
docker compose restart

# Update image
docker compose pull && docker compose up -d
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

## Security Features

- NBI API dilindungi dengan X-API-Key
- Port NBI internal (7557) tidak exposed ke host
- Health check endpoint `/health` tanpa auth
- Non-root nginx process

## Troubleshooting

### NBI return 401

Pastikan header `X-API-Key` sesuai dengan value di `.env`:

```bash
# Cek API key
cat .env | grep GENIEACS_NBI_API_KEY
```

### Container tidak start

```bash
docker compose logs nbi-proxy
docker compose logs genieacs
```

### Regenerate API Key

```bash
# Generate key baru
openssl rand -hex 32

# Update .env
# Restart nbi-proxy
docker compose restart nbi-proxy
```