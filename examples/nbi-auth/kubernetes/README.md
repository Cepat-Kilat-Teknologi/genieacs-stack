# GenieACS Kubernetes - NBI API Authentication

Kubernetes deployment for GenieACS with X-API-Key authentication for NBI API using Kustomize.

> For deployment without NBI API authentication, see: `examples/default/kubernetes/`
>
> For Helm deployment, see: `examples/nbi-auth/helm/`

## Prerequisites

- Kubernetes cluster v1.25+
- kubectl configured
- Storage provisioner (for PVC)

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Namespace: genieacs                           │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│   ┌─────────────┐         ┌────────────────────────────────────────┐ │
│   │   MongoDB   │◄────────│              GenieACS Pod              │ │
│   │  (mongo:8)  │         │  ┌──────────────┐  ┌────────────────┐  │ │
│   │  Port:27017 │         │  │   Nginx      │  │   GenieACS     │  │ │
│   └─────────────┘         │  │   Sidecar    │  │                │  │ │
│         │                 │  │   (7558)     │──│  - CWMP (7547) │  │ │
│         ▼                 │  │      │       │  │  - NBI  (7557) │  │ │
│   ┌─────────────┐         │  │  X-API-Key   │  │  - FS   (7567) │  │ │
│   │    PVC      │         │  │    Auth      │  │  - UI   (3000) │  │ │
│   └─────────────┘         │  └──────────────┘  └────────────────┘  │ │
│                           └────────────────────────────────────────┘ │
│                                          │                           │
│                          ┌───────────────▼───────────────┐           │
│                          │   LoadBalancer Service        │           │
│                          │   7557 → Nginx (7558)         │           │
│                          └───────────────────────────────┘           │
└──────────────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Navigate to Directory

```bash
cd examples/nbi-auth/kubernetes
```

### 2. Configure Secrets

```bash
# Generate JWT secret
JWT_SECRET=$(openssl rand -hex 32)
echo "JWT Secret: $JWT_SECRET"
# Edit secret.yaml and replace GENIEACS_UI_JWT_SECRET

# Generate MongoDB password
MONGO_PASSWORD=$(openssl rand -base64 24)
echo "MongoDB Password: $MONGO_PASSWORD"
# Edit mongodb-secret.yaml and replace MONGO_INITDB_ROOT_PASSWORD
# Edit configmap.yaml and update MongoDB connection URL with password

# Generate NBI API key
API_KEY=$(openssl rand -hex 32)
echo "NBI API Key: $API_KEY"
# Edit nginx-nbi-auth.yaml and replace API key in:
# if ($http_x_api_key != "your-api-key-here")
```

### 3. Deploy

```bash
kubectl apply -k .
```

### 4. Verify Deployment

```bash
# Wait for pods to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=genieacs \
  -n genieacs --timeout=180s

# Check status
kubectl get all -n genieacs
```

### 5. Access GenieACS

| Service | URL | Auth |
|---------|-----|------|
| Web UI | http://localhost:3000 | JWT (login) |
| CWMP | http://localhost:7547 | - |
| NBI API | http://localhost:7557 | **X-API-Key** |
| File Server | http://localhost:7567 | - |

### 6. Create Admin User

```bash
# Enter genieacs pod
kubectl exec -it deployment/genieacs -n genieacs -c genieacs -- /bin/bash

# Create user (inside pod)
cd /opt/genieacs
node -e "
const crypto = require('crypto');
const salt = crypto.randomBytes(64).toString('hex');
const hash = crypto.pbkdf2Sync('yourpassword', salt, 10000, 128, 'sha512').toString('hex');
console.log(JSON.stringify({_id:'admin',password:hash,salt:salt,roles:'admin'}));
" | mongosh mongodb:27017/genieacs --eval 'db.users.insertOne(JSON.parse(require("fs").readFileSync("/dev/stdin","utf8")))'
```

## NBI API Authentication

NBI API is protected with X-API-Key header authentication via Nginx sidecar.

### Test Authentication

```bash
# Without API key - returns 401
curl http://localhost:7557/devices
# Output: Invalid or missing X-API-Key

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

### Update API Key

```bash
# Generate new key
openssl rand -hex 32

# Edit nginx-nbi-auth.yaml
# Replace value in: if ($http_x_api_key != "new-key-here")

# Apply changes
kubectl apply -f nginx-nbi-auth.yaml
kubectl rollout restart deployment/genieacs -n genieacs
```

## Configuration

### ConfigMap

Edit `configmap.yaml` for configuration:

| Key | Description | Default |
|-----|-------------|---------|
| `GENIEACS_MONGODB_CONNECTION_URL` | MongoDB URL with auth | `mongodb://admin:password@mongodb:27017/genieacs?authSource=admin` |
| `GENIEACS_UI_AUTH` | Enable UI auth | `true` |
| `GENIEACS_EXT_DIR` | Extensions directory | `/opt/genieacs/ext` |
| `NODE_ENV` | Node environment | `production` |

> **Important:** The MongoDB connection URL must include the credentials matching `mongodb-secret.yaml`.

### Secrets

**secret.yaml** - GenieACS secrets:

| Key | Description |
|-----|-------------|
| `GENIEACS_UI_JWT_SECRET` | JWT secret for UI authentication |

**mongodb-secret.yaml** - MongoDB authentication:

| Key | Description |
|-----|-------------|
| `MONGO_INITDB_ROOT_USERNAME` | MongoDB root username |
| `MONGO_INITDB_ROOT_PASSWORD` | MongoDB root password |

### NBI Auth

Edit `nginx-nbi-auth.yaml` for API key authentication.

## File Structure

```
kubernetes/
├── namespace.yaml           # Namespace definition
├── secret.yaml              # GenieACS JWT secret
├── mongodb-secret.yaml      # MongoDB authentication credentials
├── configmap.yaml           # Configuration (includes MongoDB connection URL)
├── nginx-nbi-auth.yaml      # Nginx sidecar config (API key)
├── mongodb-pvc.yaml         # MongoDB storage
├── mongodb-deployment.yaml  # MongoDB deployment
├── mongodb-service.yaml     # MongoDB service (ClusterIP)
├── genieacs-pvc.yaml        # GenieACS storage (logs + ext)
├── genieacs-deployment.yaml # GenieACS + Nginx sidecar
├── genieacs-service.yaml    # GenieACS service (LoadBalancer)
├── ingress.yaml             # Ingress (optional)
├── kustomization.yaml       # Kustomize configuration
└── README.md                # Documentation
```

## Kubectl Commands

### View Resources

```bash
# All resources
kubectl get all -n genieacs

# Pods with details
kubectl get pods -n genieacs -o wide

# PVCs
kubectl get pvc -n genieacs
```

### Logs

```bash
# GenieACS logs
kubectl logs -f deployment/genieacs -n genieacs -c genieacs

# Nginx sidecar logs
kubectl logs -f deployment/genieacs -n genieacs -c nginx-nbi-auth

# MongoDB logs
kubectl logs -f deployment/mongodb -n genieacs
```

### Management

```bash
# Restart GenieACS
kubectl rollout restart deployment/genieacs -n genieacs

# Delete all
kubectl delete -k .
```

### Access Pods

```bash
# GenieACS container
kubectl exec -it deployment/genieacs -n genieacs -c genieacs -- /bin/bash

# Nginx sidecar
kubectl exec -it deployment/genieacs -n genieacs -c nginx-nbi-auth -- sh

# MongoDB
kubectl exec -it deployment/mongodb -n genieacs -- mongosh
```

## Persistent Volumes

| PVC | Size | Description |
|-----|------|-------------|
| `mongodb-data` | 10Gi | MongoDB data |
| `mongodb-configdb` | 1Gi | MongoDB config |
| `genieacs-logs` | 5Gi | GenieACS logs |
| `genieacs-ext` | 1Gi | GenieACS extensions |

## Troubleshooting

### Pods won't start

```bash
# Check status
kubectl get pods -n genieacs

# Describe pod
kubectl describe pod -l app.kubernetes.io/name=genieacs -n genieacs

# Check events
kubectl get events -n genieacs --sort-by='.lastTimestamp'
```

### NBI returns 401

```bash
# Verify API key
kubectl get configmap nginx-nbi-config -n genieacs -o yaml | grep http_x_api_key

# Check nginx logs
kubectl logs deployment/genieacs -n genieacs -c nginx-nbi-auth
```

### MongoDB connection error

```bash
# Check MongoDB pod
kubectl get pods -l app.kubernetes.io/name=mongodb -n genieacs

# Test connection from GenieACS pod
kubectl exec deployment/genieacs -n genieacs -c genieacs -- nc -zv mongodb 27017
```

## Production Configuration

For production, uncomment these settings:

### mongodb-pvc.yaml
```yaml
storageClassName: longhorn-backup  # For automatic backups
```

### mongodb-deployment.yaml & genieacs-deployment.yaml
```yaml
nodeSelector:
  longhorn.io/storage: "enabled"
```

### genieacs-deployment.yaml
```yaml
imagePullSecrets:
  - name: dockerhub-secret
```

### genieacs-service.yaml
```yaml
loadBalancerIP: 10.100.0.198  # Set fixed IP
```

## Security Features

- NBI API protected with X-API-Key authentication
- MongoDB requires authentication (configured in `mongodb-secret.yaml`)
- Nginx sidecar runs in the same pod as GenieACS
- Internal NBI port (7557) not exposed externally
- Health check endpoint `/health` available without authentication
- Security context: `allowPrivilegeEscalation: false`