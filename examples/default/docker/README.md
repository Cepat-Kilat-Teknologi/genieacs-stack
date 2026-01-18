# GenieACS Docker - Default Deployment

Deployment GenieACS menggunakan Docker Compose (tanpa NBI API authentication).

> Untuk deployment dengan NBI API authentication, lihat: `examples/nbi-auth/docker/`

## Prerequisites

- Docker Engine 20.10+
- Docker Compose v2+
- Minimal 2GB RAM
- 10GB disk space

## Quick Start

### 1. Masuk ke direktori

```bash
cd examples/default/docker
```

### 2. Konfigurasi Environment

```bash
# Copy template
cp .env.example .env

# Generate JWT secret
openssl rand -hex 32

# Edit .env dan paste JWT secret
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
| NBI API | http://localhost:7557 | Northbound API |
| File Server | http://localhost:7567 | Firmware upload |

## Perintah Berguna

```bash
# Melihat logs
docker compose logs -f

# Status containers
docker compose ps

# Stop services
docker compose down

# Restart
docker compose restart

# Update image
docker compose pull && docker compose up -d
```

## Backup & Restore

### Backup Database

```bash
docker exec mongo-genieacs mongodump --out /data/db/backup
docker cp mongo-genieacs:/data/db/backup ./backup
```

### Restore Database

```bash
docker cp ./backup mongo-genieacs:/data/db/backup
docker exec mongo-genieacs mongorestore /data/db/backup
```

## Security Notes

- NBI API pada port 7557 **tidak memiliki authentication**
- Untuk mengamankan NBI API, gunakan: `examples/nbi-auth/docker/`
- Atau bind ke localhost: `GENIEACS_NBI_PORT=127.0.0.1:7557`

## Troubleshooting

### Container tidak start

```bash
docker compose logs genieacs
```

### MongoDB error

```bash
docker compose ps mongo
docker compose logs mongo
```

### Port conflict

Ubah port di `.env`:
```bash
GENIEACS_UI_PORT=3001
```