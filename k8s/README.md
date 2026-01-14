# GenieACS Kubernetes Deployment

GenieACS adalah Auto Configuration Server (ACS) open-source untuk mengelola perangkat CPE menggunakan protokol TR-069 (CWMP).

## Arsitektur

```
┌─────────────────────────────────────────────────────────────┐
│                      Namespace: genieacs                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌─────────────┐         ┌─────────────────────────────┐   │
│   │   MongoDB   │◄────────│        GenieACS             │   │
│   │  (mongo:8)  │         │  - CWMP Server (7547)       │   │
│   │  Port:27017 │         │  - NBI API (7557)           │   │
│   └─────────────┘         │  - File Server (7567)       │   │
│         │                 │  - Web UI (3000)            │   │
│         ▼                 └─────────────────────────────┘   │
│   ┌─────────────┐                     │                     │
│   │   PVC       │                     ▼                     │
│   │ longhorn-   │         ┌─────────────────────────────┐   │
│   │   backup    │         │     LoadBalancer Service    │   │
│   └─────────────┘         │     IP: 10.100.0.198        │   │
│                           └─────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Kubernetes cluster (v1.25+)
- kubectl configured
- Storage class `longhorn-backup` tersedia (untuk backup otomatis MongoDB)
- MetalLB atau LoadBalancer controller (untuk IP 10.100.0.198)
- Docker Hub secret `dockerhub-secret` (untuk pull private image)

## Quick Start

### 1. Generate JWT Secret

```bash
# Generate random JWT secret
openssl rand -hex 32
```

### 2. Update Secret

Edit file `secret.yaml` dan ganti value `GENIEACS_UI_JWT_SECRET`:

```yaml
stringData:
  GENIEACS_UI_JWT_SECRET: "<hasil-dari-openssl-rand>"
```

### 3. Siapkan DockerHub Secret

Pastikan secret `dockerhub-secret` tersedia di namespace genieacs:

```bash
# Copy dari namespace lain (jika sudah ada)
kubectl get secret dockerhub-secret -n production -o yaml | \
  sed 's/namespace: production/namespace: genieacs/' | \
  kubectl apply -f -

# Atau buat baru
kubectl create secret docker-registry dockerhub-secret \
  -n genieacs \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<username> \
  --docker-password=<password>
```

### 4. Deploy menggunakan Kustomize

```bash
# Preview konfigurasi
kubectl kustomize genieacs/

# Deploy semua resources
kubectl apply -k genieacs/
```

### 5. Verifikasi Deployment

```bash
# Cek namespace
kubectl get ns genieacs

# Cek semua resources
kubectl get all -n genieacs

# Cek PVC
kubectl get pvc -n genieacs

# Cek logs
kubectl logs -n genieacs deployment/genieacs
```

### 6. Setup Admin User

Akses Web UI di http://10.100.0.198:3000 dan buat admin user pada halaman pertama kali.

## Akses GenieACS

Setelah deployment berhasil, GenieACS dapat diakses melalui:

| Service | Port | URL |
|---------|------|-----|
| Web UI | 3000 | http://10.100.0.198:3000 |
| CWMP (TR-069) | 7547 | http://10.100.0.198:7547 |
| NBI API | 7557 | http://10.100.0.198:7557 |
| File Server | 7567 | http://10.100.0.198:7567 |

### Akses dengan Port Forward (testing)

```bash
kubectl port-forward -n genieacs svc/genieacs 3000:3000 7547:7547 7557:7557 7567:7567

# Akses UI di http://localhost:3000
```

## Konfigurasi CPE Device

Pada perangkat CPE (router/modem), set ACS URL:

```
http://10.100.0.198:7547
```

## Struktur File

```
genieacs/
├── namespace.yaml          # Namespace definition
├── configmap.yaml          # Environment configuration
├── secret.yaml             # JWT secret (HARUS diganti!)
├── mongodb-pvc.yaml        # MongoDB persistent storage (longhorn-backup)
├── mongodb-deployment.yaml # MongoDB deployment
├── mongodb-service.yaml    # MongoDB internal service
├── genieacs-pvc.yaml       # GenieACS persistent storage (logs & ext)
├── genieacs-deployment.yaml# GenieACS deployment
├── genieacs-service.yaml   # GenieACS LoadBalancer (10.100.0.198)
├── ingress.yaml            # Ingress (optional)
├── kustomization.yaml      # Kustomize configuration
└── README.md               # Dokumentasi ini
```

## Storage

MongoDB menggunakan storage class `longhorn-backup` untuk backup otomatis:

| PVC | Size | Storage Class | Purpose |
|-----|------|---------------|---------|
| mongodb-data | 10Gi | longhorn-backup | Database data |
| mongodb-configdb | 1Gi | longhorn-backup | MongoDB config |
| genieacs-logs | 5Gi | default | Log files (stderr only) |
| genieacs-ext | 1Gi | default | Extensions |

> **Note**: Access logs di-disable untuk mencegah disk penuh. Hanya stderr logs yang disimpan.

## Resource Limits

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|-------------|-----------|----------------|--------------|
| MongoDB   | 250m        | 2000m     | 512Mi          | 2Gi          |
| GenieACS  | 250m        | 2000m     | 256Mi          | 1Gi          |

## Troubleshooting

### Pod tidak running

```bash
# Cek status pod
kubectl get pods -n genieacs

# Describe pod untuk melihat error
kubectl describe pod -n genieacs <pod-name>

# Cek events
kubectl get events -n genieacs --sort-by='.lastTimestamp'
```

### ImagePullBackOff

```bash
# Pastikan dockerhub-secret ada
kubectl get secret -n genieacs dockerhub-secret

# Jika tidak ada, copy dari namespace lain
kubectl get secret dockerhub-secret -n production -o yaml | \
  sed 's/namespace: production/namespace: genieacs/' | \
  kubectl apply -f -

# Restart pod
kubectl delete pod -n genieacs -l app.kubernetes.io/name=genieacs
```

### MongoDB tidak ready

```bash
# Cek logs MongoDB
kubectl logs -n genieacs deployment/mongodb

# Exec ke pod untuk debug
kubectl exec -it -n genieacs deployment/mongodb -- mongosh
```

### GenieACS tidak bisa connect ke MongoDB

```bash
# Pastikan MongoDB service running
kubectl get svc -n genieacs mongodb

# Test koneksi dari pod GenieACS
kubectl exec -it -n genieacs deployment/genieacs -- nc -zv mongodb 27017
```

### Reset Admin Password

Reset password via MongoDB:

```bash
# Generate new password hash
SALT=$(openssl rand -hex 16)
PASSWORD="newpassword123"
HASH=$(echo -n "${PASSWORD}${SALT}" | openssl dgst -sha256 -hex | awk '{print $2}')

# Update di MongoDB
kubectl exec -n genieacs deployment/mongodb -- mongosh genieacs --eval "
  db.users.updateOne(
    { _id: 'admin' },
    { \$set: { password: '${HASH}', salt: '${SALT}' } }
  )
"
```

### Cek Service LoadBalancer

```bash
# Pastikan IP sudah ter-assign
kubectl get svc -n genieacs genieacs

# Output yang diharapkan:
# NAME       TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)
# genieacs   LoadBalancer   10.x.x.x       10.100.0.198   7547:xxxxx/TCP,...
```

### View Logs

```bash
# GenieACS logs
kubectl logs -n genieacs -l app.kubernetes.io/name=genieacs -f

# MongoDB logs
kubectl logs -n genieacs -l app.kubernetes.io/name=mongodb -f

# All pods
kubectl logs -n genieacs --all-containers -f
```

## Uninstall

```bash
# Hapus semua resources
kubectl delete -k genieacs/

# Atau hapus namespace (akan menghapus semua resources di dalamnya)
kubectl delete ns genieacs
```

## Production Recommendations

1. **Backup Strategy**: MongoDB sudah menggunakan `longhorn-backup` untuk backup otomatis
2. **Enable TLS**: Configure Ingress dengan TLS certificates untuk production
3. **Set Resource Limits**: Adjust berdasarkan workload
4. **Monitoring**: Tambahkan Prometheus/Grafana untuk monitoring
5. **Network Policies**: Implement network policies untuk security
6. **External MongoDB**: Pertimbangkan managed MongoDB (Atlas, DocumentDB) untuk high availability

## Referensi

- [GenieACS Documentation](https://docs.genieacs.com/)
- [GenieACS GitHub](https://github.com/genieacs/genieacs)
- [TR-069 Specification](https://www.broadband-forum.org/technical/download/TR-069.pdf)
- [Longhorn Documentation](https://longhorn.io/docs/)