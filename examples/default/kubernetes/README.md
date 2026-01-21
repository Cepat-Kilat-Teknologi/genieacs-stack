# GenieACS Kubernetes - Default Deployment

Kubernetes deployment for GenieACS using Kustomize (without NBI API authentication).

> For deployment with NBI API authentication, see: `examples/nbi-auth/kubernetes/`
>
> For Helm deployment, see: `examples/default/helm/`

## Prerequisites

- Kubernetes cluster v1.25+
- kubectl configured
- Storage provisioner (for PVC)

## Quick Start

### 1. Navigate to Directory

```bash
cd examples/default/kubernetes
```

### 2. Configure Secrets (Required)

Edit secrets before deployment:

```bash
# Generate JWT secret
JWT_SECRET=$(openssl rand -hex 32)
echo "JWT Secret: $JWT_SECRET"

# Generate MongoDB password
MONGO_PASSWORD=$(openssl rand -base64 24)
echo "MongoDB Password: $MONGO_PASSWORD"

# Edit secret.yaml - update GENIEACS_UI_JWT_SECRET
nano secret.yaml

# Edit mongodb-secret.yaml - update MONGO_INITDB_ROOT_PASSWORD
nano mongodb-secret.yaml

# Edit configmap.yaml - update MongoDB connection URL with password
nano configmap.yaml
```

### 3. Deploy

```bash
kubectl apply -k .
```

### 4. Verify Deployment

```bash
# Wait for pods to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/managed-by=kustomize \
  -n genieacs --timeout=180s

# Check status
kubectl get all -n genieacs
```

### 5. Access GenieACS

| Service | URL | Description |
|---------|-----|-------------|
| Web UI | http://localhost:3000 | Management interface |
| CWMP | http://localhost:7547 | TR-069 for CPE devices |
| NBI API | http://localhost:7557 | Northbound API |
| File Server | http://localhost:7567 | Firmware upload |

### 6. Create Admin User

```bash
# Enter genieacs pod
kubectl exec -it deployment/genieacs -n genieacs -- /bin/bash

# Create user (inside pod)
# Replace YOUR_MONGO_PASSWORD with the password from mongodb-secret.yaml
cd /opt/genieacs
node -e "
const crypto = require('crypto');
const salt = crypto.randomBytes(64).toString('hex');
const hash = crypto.pbkdf2Sync('yourpassword', salt, 10000, 128, 'sha512').toString('hex');
console.log(JSON.stringify({_id:'admin',password:hash,salt:salt,roles:'admin'}));
" | mongosh "mongodb://admin:YOUR_MONGO_PASSWORD@mongodb:27017/genieacs?authSource=admin" --eval 'db.users.insertOne(JSON.parse(require("fs").readFileSync("/dev/stdin","utf8")))'
```

## Services & Ports

| Service | Port | Description |
|---------|------|-------------|
| UI | 3000 | Web interface |
| CWMP | 7547 | TR-069 for CPE devices |
| NBI | 7557 | Northbound API (no auth) |
| FS | 7567 | File server |
| MongoDB | 27017 | Database (internal) |

## Accessing Services

### Via LoadBalancer (Default)

```bash
# Get External IP
kubectl get svc genieacs -n genieacs

# For Docker Desktop, access directly:
curl http://localhost:3000
```

### Via Port Forward

```bash
kubectl port-forward svc/genieacs -n genieacs \
  3000:3000 7547:7547 7557:7557 7567:7567
```

### Via NodePort

Uncomment NodePort service in `genieacs-service.yaml`:

```bash
# Access via NodePort
curl http://<NODE_IP>:30000
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

### Resources

Edit resource limits in `genieacs-deployment.yaml` and `mongodb-deployment.yaml`:

```yaml
resources:
  requests:
    cpu: "250m"
    memory: "256Mi"
  limits:
    cpu: "2000m"
    memory: "1Gi"
```

### Storage

Edit storage size in `genieacs-pvc.yaml` and `mongodb-pvc.yaml`:

```yaml
resources:
  requests:
    storage: 10Gi
```

## File Structure

```
kubernetes/
├── namespace.yaml           # Namespace definition
├── secret.yaml              # GenieACS JWT secret
├── mongodb-secret.yaml      # MongoDB authentication credentials
├── configmap.yaml           # Configuration (includes MongoDB connection URL)
├── mongodb-pvc.yaml         # MongoDB storage (data + configdb)
├── mongodb-deployment.yaml  # MongoDB deployment
├── mongodb-service.yaml     # MongoDB service (ClusterIP)
├── genieacs-pvc.yaml        # GenieACS storage (logs + ext)
├── genieacs-deployment.yaml # GenieACS deployment
├── genieacs-service.yaml    # GenieACS service (LoadBalancer)
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

# Services
kubectl get svc -n genieacs
```

### Logs

```bash
# GenieACS logs
kubectl logs -f deployment/genieacs -n genieacs

# MongoDB logs
kubectl logs -f deployment/mongodb -n genieacs

# All pods
kubectl logs -l app.kubernetes.io/managed-by=kustomize -n genieacs
```

### Management

```bash
# Restart GenieACS
kubectl rollout restart deployment/genieacs -n genieacs

# Restart MongoDB
kubectl rollout restart deployment/mongodb -n genieacs

# Scale (if using external MongoDB)
kubectl scale deployment/genieacs -n genieacs --replicas=2

# Delete all
kubectl delete -k .
```

### Access Pods

```bash
# GenieACS
kubectl exec -it deployment/genieacs -n genieacs -- /bin/bash

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

### Check PVC Status

```bash
kubectl get pvc -n genieacs
```

## Backup & Restore

### Backup MongoDB

```bash
# Backup inside pod
kubectl exec deployment/mongodb -n genieacs -- \
  mongodump --out /data/db/backup

# Copy to local
kubectl cp genieacs/mongodb-<POD_ID>:/data/db/backup ./backup
```

### Restore MongoDB

```bash
# Copy backup to pod
kubectl cp ./backup genieacs/mongodb-<POD_ID>:/data/db/backup

# Restore
kubectl exec deployment/mongodb -n genieacs -- \
  mongorestore /data/db/backup
```

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

### MongoDB connection error

```bash
# Check MongoDB pod
kubectl get pods -l app.kubernetes.io/name=mongodb -n genieacs

# Test connection from GenieACS pod
kubectl exec deployment/genieacs -n genieacs -- \
  nc -zv mongodb 27017
```

### PVC Pending

```bash
# Check PVC
kubectl describe pvc -n genieacs

# Check StorageClass
kubectl get storageclass
```

### Image pull error

```bash
# Check image pull status
kubectl describe pod -n genieacs | grep -A5 "Events:"
```

## Kustomize Overlays

For different environments, create overlays:

```bash
mkdir -p overlays/production

cat > overlays/production/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: genieacs-prod
resources:
  - ../../
patches:
  - path: patches/resources.yaml
EOF
```

Deploy with overlay:

```bash
kubectl apply -k overlays/production
```

## Security Notes

- NBI API on port 7557 **has no authentication**
- For NBI API authentication, use: `examples/nbi-auth/kubernetes/`
- MongoDB requires authentication (configured in `mongodb-secret.yaml`)
- Always change default passwords before deployment
- Or use NetworkPolicy to restrict access:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-nbi-external
  namespace: genieacs
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: genieacs
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: trusted-namespace
      ports:
        - port: 7557
```