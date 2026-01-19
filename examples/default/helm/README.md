# GenieACS Helm Chart - Default Deployment

Helm chart for deploying GenieACS on Kubernetes (without NBI API authentication).

> For deployment with NBI API authentication, see: `examples/nbi-auth/helm/`

## Prerequisites

- Kubernetes cluster v1.25+
- Helm v3.10+
- kubectl configured
- Storage provisioner (for PVC)

## Quick Start

### 1. Install Chart

```bash
# From project root
helm install genieacs ./examples/default/helm/genieacs \
  --create-namespace \
  --namespace genieacs

# Or from helm directory
cd examples/default/helm
helm install genieacs ./genieacs \
  --create-namespace \
  --namespace genieacs
```

### 2. Verify Deployment

```bash
# Wait for pods to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=genieacs \
  -n genieacs --timeout=180s

# Check status
kubectl get all -n genieacs
```

### 3. Access GenieACS

| Service | URL | Description |
|---------|-----|-------------|
| Web UI | http://localhost:3000 | Management interface |
| CWMP | http://localhost:7547 | TR-069 for CPE devices |
| NBI API | http://localhost:7557 | Northbound API |
| File Server | http://localhost:7567 | Firmware upload |

### 4. Create Admin User

```bash
# Enter genieacs pod
kubectl exec -it deployment/genieacs -n genieacs -- /bin/bash

# Create user (inside pod)
cd /opt/genieacs
node -e "
const crypto = require('crypto');
const salt = crypto.randomBytes(64).toString('hex');
const hash = crypto.pbkdf2Sync('yourpassword', salt, 10000, 128, 'sha512').toString('hex');
console.log(JSON.stringify({_id:'admin',password:hash,salt:salt,roles:'admin'}));
" | mongosh genieacs-mongodb:27017/genieacs --eval 'db.users.insertOne(JSON.parse(require("fs").readFileSync("/dev/stdin","utf8")))'
```

## Installation Options

### Install with Custom Values

```bash
helm install genieacs ./examples/default/helm/genieacs \
  --namespace genieacs \
  --create-namespace \
  --set genieacs.service.type=NodePort \
  --set mongodb.persistence.data.size=20Gi
```

### Install with Values File

```bash
# Create custom values file
cat > my-values.yaml <<EOF
genieacs:
  replicaCount: 1
  service:
    type: ClusterIP
  resources:
    requests:
      cpu: "500m"
      memory: "512Mi"
    limits:
      cpu: "2000m"
      memory: "2Gi"

mongodb:
  persistence:
    data:
      size: 20Gi

secret:
  jwtSecret: "your-secure-jwt-secret-here"
EOF

# Install with custom values
helm install genieacs ./examples/default/helm/genieacs \
  --namespace genieacs \
  --create-namespace \
  -f my-values.yaml
```

## Configuration

### Configurable Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nameOverride` | Override chart name | `""` |
| `fullnameOverride` | Override full name | `""` |

#### GenieACS Application

| Parameter | Description | Default |
|-----------|-------------|---------|
| `genieacs.image.repository` | Image repository | `cepatkilatteknologi/genieacs` |
| `genieacs.image.tag` | Image tag | `latest` |
| `genieacs.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `genieacs.replicaCount` | Number of replicas | `1` |
| `genieacs.service.type` | Service type | `LoadBalancer` |
| `genieacs.service.loadBalancerIP` | Fixed LoadBalancer IP (MetalLB) | `""` |
| `genieacs.service.loadBalancerSourceRanges` | IP whitelist for access | `[]` |
| `genieacs.service.annotations` | Service annotations (cloud providers) | `{}` |
| `genieacs.service.ports.cwmp` | CWMP port | `7547` |
| `genieacs.service.ports.nbi` | NBI API port | `7557` |
| `genieacs.service.ports.fs` | File Server port | `7567` |
| `genieacs.service.ports.ui` | Web UI port | `3000` |
| `genieacs.resources.requests.cpu` | CPU request | `250m` |
| `genieacs.resources.requests.memory` | Memory request | `256Mi` |
| `genieacs.resources.limits.cpu` | CPU limit | `2000m` |
| `genieacs.resources.limits.memory` | Memory limit | `1Gi` |
| `genieacs.persistence.logs.enabled` | Enable logs persistence | `true` |
| `genieacs.persistence.logs.size` | Logs volume size | `5Gi` |
| `genieacs.persistence.ext.enabled` | Enable ext persistence | `true` |
| `genieacs.persistence.ext.size` | Ext volume size | `1Gi` |

#### MongoDB

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mongodb.enabled` | Deploy MongoDB | `true` |
| `mongodb.image.repository` | MongoDB image | `mongo` |
| `mongodb.image.tag` | MongoDB version | `8.0` |
| `mongodb.service.type` | Service type | `ClusterIP` |
| `mongodb.service.port` | MongoDB port | `27017` |
| `mongodb.resources.requests.cpu` | CPU request | `250m` |
| `mongodb.resources.requests.memory` | Memory request | `512Mi` |
| `mongodb.resources.limits.cpu` | CPU limit | `2000m` |
| `mongodb.resources.limits.memory` | Memory limit | `2Gi` |
| `mongodb.persistence.data.enabled` | Enable data persistence | `true` |
| `mongodb.persistence.data.size` | Data volume size | `10Gi` |
| `mongodb.persistence.configdb.enabled` | Enable configdb persistence | `true` |
| `mongodb.persistence.configdb.size` | Configdb volume size | `1Gi` |

#### Security

| Parameter | Description | Default |
|-----------|-------------|---------|
| `secret.jwtSecret` | JWT secret for UI auth | (placeholder) |
| `config.uiAuth` | Enable UI authentication | `true` |
| `config.nodeEnv` | Node environment | `production` |

## Helm Commands

### Upgrade Release

```bash
helm upgrade genieacs ./examples/default/helm/genieacs \
  --namespace genieacs \
  --set genieacs.image.tag=1.2.14
```

### Rollback

```bash
# View history
helm history genieacs -n genieacs

# Rollback to previous revision
helm rollback genieacs -n genieacs
```

### Uninstall

```bash
helm uninstall genieacs -n genieacs

# Delete namespace (optional)
kubectl delete namespace genieacs
```

### View Release Info

```bash
# Release status
helm status genieacs -n genieacs

# Get all values
helm get values genieacs -n genieacs

# Get manifest
helm get manifest genieacs -n genieacs
```

## Using External MongoDB

To use external MongoDB:

```yaml
# my-values.yaml
mongodb:
  enabled: false

config:
  mongodbConnectionUrl: "mongodb://external-mongo.example.com:27017/genieacs"
```

```bash
helm install genieacs ./examples/default/helm/genieacs \
  --namespace genieacs \
  --create-namespace \
  -f my-values.yaml
```

## Service Types

### LoadBalancer (Default)

Suitable for cloud providers (AWS, GCP, Azure) or Docker Desktop.

```yaml
genieacs:
  service:
    type: LoadBalancer
```

### NodePort

Suitable for bare-metal or development.

```yaml
genieacs:
  service:
    type: NodePort
```

Access via: `http://<NODE_IP>:<NODE_PORT>`

### ClusterIP

Suitable for internal access or with Ingress.

```yaml
genieacs:
  service:
    type: ClusterIP
```

Access via port-forward:
```bash
kubectl port-forward -n genieacs svc/genieacs 3000:3000 7547:7547 7557:7557 7567:7567
```

## File Structure

```
helm/
├── README.md
└── genieacs/
    ├── Chart.yaml              # Chart metadata
    ├── values.yaml             # Default values
    ├── .helmignore             # Ignore patterns
    └── templates/
        ├── _helpers.tpl        # Template helpers
        ├── configmap.yaml      # Configuration
        ├── secret.yaml         # Secrets
        ├── mongodb-pvc.yaml    # MongoDB storage
        ├── mongodb-deployment.yaml
        ├── mongodb-service.yaml
        ├── genieacs-pvc.yaml   # GenieACS storage
        ├── genieacs-deployment.yaml
        ├── genieacs-service.yaml
        └── NOTES.txt           # Post-install notes
```

## Troubleshooting

### Pods won't start

```bash
# Check pod status
kubectl get pods -n genieacs

# Check events
kubectl describe pod -l app.kubernetes.io/instance=genieacs -n genieacs

# Check logs
kubectl logs -l app.kubernetes.io/name=genieacs -n genieacs
```

### MongoDB connection error

```bash
# Check MongoDB pod
kubectl get pods -l app.kubernetes.io/component=database -n genieacs

# Check MongoDB logs
kubectl logs -l app.kubernetes.io/component=database -n genieacs
```

### PVC Pending

```bash
# Check PVC status
kubectl get pvc -n genieacs

# Check StorageClass
kubectl get storageclass
```

## Security Notes

- NBI API on port 7557 **has no authentication**
- For NBI API authentication, use: `examples/nbi-auth/helm/`
- Or use NetworkPolicy to restrict access
- Always change `secret.jwtSecret` in production environment