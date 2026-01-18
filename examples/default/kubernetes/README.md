# GenieACS Kubernetes - Default Deployment

Deployment GenieACS di Kubernetes (tanpa NBI API authentication).

> Untuk deployment dengan NBI API authentication, lihat: `examples/nbi-auth/kubernetes/`

## Prerequisites

- Kubernetes cluster v1.25+
- kubectl configured
- Storage provisioner (untuk PVC)

## Quick Start

### 1. Masuk ke direktori

```bash
cd examples/default/kubernetes
```

### 2. Edit Secret

Edit `secret.yaml` dan ganti JWT secret:

```bash
# Generate JWT secret
openssl rand -hex 32
```

### 3. Deploy

```bash
kubectl apply -k .
```

### 4. Verifikasi

```bash
# Cek pods
kubectl get pods -n genieacs

# Cek services
kubectl get svc -n genieacs
```

### 5. Buat Admin User

```bash
# Masuk ke pod genieacs
kubectl exec -it deployment/genieacs -n genieacs -- /bin/bash

# Buat user (di dalam pod)
cd /opt/genieacs
node -e "
const crypto = require('crypto');
const salt = crypto.randomBytes(64).toString('hex');
const hash = crypto.pbkdf2Sync('yourpassword', salt, 10000, 128, 'sha512').toString('hex');
console.log(JSON.stringify({_id:'admin',password:hash,salt:salt,roles:'admin'}));
" | mongosh mongodb:27017/genieacs --eval 'db.users.insertOne(JSON.parse(require("fs").readFileSync("/dev/stdin","utf8")))'
```

## Services & Ports

| Service | Port | Deskripsi |
|---------|------|-----------|
| UI | 3000 | Web interface |
| CWMP | 7547 | TR-069 untuk CPE |
| NBI | 7557 | Northbound API (tanpa auth) |
| FS | 7567 | File server |

## Akses Services

### Via LoadBalancer

```bash
# Dapatkan IP
kubectl get svc genieacs -n genieacs -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Akses
curl http://<LOADBALANCER_IP>:3000
```

### Via Port Forward

```bash
kubectl port-forward svc/genieacs -n genieacs 3000:3000 7557:7557
```

## File Structure

```
kubernetes/
├── namespace.yaml          # Namespace
├── secret.yaml             # JWT secret
├── configmap.yaml          # Configuration
├── mongodb-pvc.yaml        # MongoDB storage
├── mongodb-deployment.yaml # MongoDB
├── mongodb-service.yaml    # MongoDB service
├── genieacs-pvc.yaml       # GenieACS storage
├── genieacs-deployment.yaml # GenieACS
├── genieacs-service.yaml   # GenieACS service
└── kustomization.yaml      # Kustomize config
```

## Management Commands

```bash
# View all resources
kubectl get all -n genieacs

# View logs
kubectl logs -f deployment/genieacs -n genieacs

# Restart deployment
kubectl rollout restart deployment/genieacs -n genieacs

# Delete all
kubectl delete -k .
```

## Security Notes

- NBI API pada port 7557 **tidak memiliki authentication**
- Untuk mengamankan NBI API, gunakan: `examples/nbi-auth/kubernetes/`
- Atau gunakan NetworkPolicy untuk membatasi akses