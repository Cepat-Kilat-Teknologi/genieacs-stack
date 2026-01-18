# GenieACS Docker Production Deployment

Panduan deployment GenieACS menggunakan Docker Compose untuk environment production.

## Prerequisites

- Docker Engine 20.10+
- Docker Compose v2+
- Minimal 2GB RAM
- 10GB disk space

## Quick Start

### 1. Clone dan masuk ke direktori

```bash
cd examples/docker
```

### 2. Konfigurasi Environment

Copy file `.env.example` ke `.env`:

```bash
cp .env.example .env
```

Edit file `.env` dan generate JWT secret:

```bash
# Generate JWT secret
openssl rand -hex 32
```

Paste hasil generate ke `GENIEACS_UI_JWT_SECRET` di file `.env`.

### 3. Jalankan GenieACS

```bash
docker compose -f docker-compose.prod.yml up -d
```

### 4. Buat Admin User

Tunggu sampai container healthy, lalu buat user admin:

```bash
docker exec genieacs /opt/genieacs/scripts/create-user.sh admin yourpassword admin
```

Ganti `yourpassword` dengan password yang kuat.

### 5. Akses GenieACS

- **Web UI**: http://localhost:3000
- **NBI API**: http://localhost:7557
- **CWMP**: http://localhost:7547
- **File Server**: http://localhost:7567

## Services & Ports

| Service | Port | Deskripsi |
|---------|------|-----------|
| UI | 3000 | Web interface untuk manajemen |
| CWMP | 7547 | TR-069 endpoint untuk CPE devices |
| NBI | 7557 | Northbound API untuk integrasi |
| FS | 7567 | File server untuk firmware |

## Perintah Berguna

### Melihat logs

```bash
# Semua logs
docker compose -f docker-compose.prod.yml logs -f

# Logs GenieACS saja
docker compose -f docker-compose.prod.yml logs -f genieacs

# Logs MongoDB saja
docker compose -f docker-compose.prod.yml logs -f mongo
```

### Status containers

```bash
docker compose -f docker-compose.prod.yml ps
```

### Stop services

```bash
docker compose -f docker-compose.prod.yml down
```

### Stop dan hapus volumes (HATI-HATI: data akan hilang)

```bash
docker compose -f docker-compose.prod.yml down -v
```

### Restart services

```bash
docker compose -f docker-compose.prod.yml restart
```

### Update ke versi terbaru

```bash
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

## Konfigurasi Lanjutan

### Menggunakan Reverse Proxy

Jika menggunakan reverse proxy (nginx/traefik), ubah port binding ke localhost saja di file `.env`:

```bash
GENIEACS_CWMP_PORT=127.0.0.1:7547
GENIEACS_NBI_PORT=127.0.0.1:7557
GENIEACS_FS_PORT=127.0.0.1:7567
GENIEACS_UI_PORT=127.0.0.1:3000
```

### Custom Extensions

Untuk menambahkan custom extensions, mount direktori ke `/opt/genieacs/ext`:

```yaml
volumes:
  - ./my-extensions:/opt/genieacs/ext:ro
```

### Backup Database

```bash
# Backup
docker exec genieacs-mongo mongodump --out /data/db/backup

# Copy backup ke host
docker cp genieacs-mongo:/data/db/backup ./backup
```

### Restore Database

```bash
# Copy backup ke container
docker cp ./backup genieacs-mongo:/data/db/backup

# Restore
docker exec genieacs-mongo mongorestore /data/db/backup
```

## Troubleshooting

### Container tidak start

Cek logs:
```bash
docker compose -f docker-compose.prod.yml logs genieacs
```

### MongoDB connection error

Pastikan MongoDB sudah healthy:
```bash
docker compose -f docker-compose.prod.yml ps mongo
```

### Port sudah digunakan

Ubah port di file `.env` jika ada konflik dengan service lain.

### JWT Secret tidak valid

Pastikan `GENIEACS_UI_JWT_SECRET` sudah diisi di file `.env` dengan minimal 32 karakter.

## Security Recommendations

1. **Gunakan strong password** untuk admin user
2. **Generate random JWT secret** dengan `openssl rand -hex 32`
3. **Gunakan reverse proxy** dengan HTTPS untuk production
4. **Batasi akses NBI API** hanya dari IP yang diperlukan
5. **Regular backup** database MongoDB
6. **Update secara berkala** ke versi terbaru

## Support

- GitHub Issues: https://github.com/cepatkilatteknologi/genieacs/issues
- Dokumentasi GenieACS: https://docs.genieacs.com