# GenieACS Helm Chart - NBI API Authentication

Helm chart for deploying GenieACS on Kubernetes with X-API-Key authentication for NBI API.

> For deployment without NBI API authentication, see: `examples/default/helm/`

## Prerequisites

- Kubernetes cluster v1.25+
- Helm v3.10+
- kubectl configured
- Storage provisioner (for PVC)

## Quick Start

### 1. Install Chart

```bash
# From project root
helm install genieacs ./examples/nbi-auth/helm/genieacs \
  --create-namespace \
  --namespace genieacs

# Or from helm directory
cd examples/nbi-auth/helm
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

| Service | URL | Auth |
|---------|-----|------|
| Web UI | http://localhost:3000 | JWT (login) |
| CWMP | http://localhost:7547 | - |
| NBI API | http://localhost:7557 | **X-API-Key** |
| File Server | http://localhost:7567 | - |

### 4. Test NBI Authentication

```bash
# Without API key - returns 401
curl http://localhost:7557/devices
# {"error": "Invalid or missing X-API-Key"}

# With API key - returns 200 (use value from values.yaml or your custom value)
curl -H "X-API-Key: your-api-key" http://localhost:7557/devices

# Health check (no auth required)
curl http://localhost:7557/health
```

### 5. Create Admin User

```bash
# Enter genieacs pod
kubectl exec -it deployment/genieacs-genieacs-nbi-auth -n genieacs -c genieacs -- /bin/bash

# Create user (inside pod)
cd /opt/genieacs
node -e "
const crypto = require('crypto');
const salt = crypto.randomBytes(64).toString('hex');
const hash = crypto.pbkdf2Sync('yourpassword', salt, 10000, 128, 'sha512').toString('hex');
console.log(JSON.stringify({_id:'admin',password:hash,salt:salt,roles:'admin'}));
" | mongosh genieacs-genieacs-nbi-auth-mongodb:27017/genieacs --eval 'db.users.insertOne(JSON.parse(require("fs").readFileSync("/dev/stdin","utf8")))'
```

## Installation Options

### Install with Custom API Key

```bash
helm install genieacs ./examples/nbi-auth/helm/genieacs \
  --namespace genieacs \
  --create-namespace \
  --set nbiAuth.apiKey="your-secure-api-key-here" \
  --set secret.jwtSecret="your-jwt-secret-here"
```

### Install with Values File

```bash
# Create custom values file
cat > my-values.yaml <<EOF
nbiAuth:
  apiKey: "your-secure-api-key-generated-with-openssl"

secret:
  jwtSecret: "your-jwt-secret-generated-with-openssl"

genieacs:
  service:
    type: ClusterIP
  resources:
    requests:
      cpu: "500m"
      memory: "512Mi"

mongodb:
  persistence:
    data:
      size: 20Gi
EOF

# Install with custom values
helm install genieacs ./examples/nbi-auth/helm/genieacs \
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

#### NBI Authentication

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nbiAuth.enabled` | Enable NBI auth proxy | `true` |
| `nbiAuth.apiKey` | API key for authentication | (placeholder) |
| `nbiAuth.image.repository` | Nginx image | `nginx` |
| `nbiAuth.image.tag` | Nginx version | `1.27-alpine` |
| `nbiAuth.internalPort` | Internal proxy port | `7558` |
| `nbiAuth.resources.requests.cpu` | CPU request | `50m` |
| `nbiAuth.resources.requests.memory` | Memory request | `32Mi` |
| `nbiAuth.resources.limits.cpu` | CPU limit | `200m` |
| `nbiAuth.resources.limits.memory` | Memory limit | `64Mi` |

#### GenieACS Application

| Parameter | Description | Default |
|-----------|-------------|---------|
| `genieacs.image.repository` | Image repository | `cepatkilatteknologi/genieacs` |
| `genieacs.image.tag` | Image tag | `1.2.13` |
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

#### MongoDB

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mongodb.enabled` | Deploy MongoDB | `true` |
| `mongodb.image.tag` | MongoDB version | `8.0` |
| `mongodb.auth.enabled` | Enable MongoDB authentication | `true` |
| `mongodb.auth.rootUsername` | MongoDB root username | `admin` |
| `mongodb.auth.rootPassword` | MongoDB root password | (placeholder) |
| `mongodb.auth.existingSecret` | Use existing secret for credentials | `""` |
| `mongodb.persistence.data.size` | Data volume size | `10Gi` |
| `mongodb.persistence.configdb.size` | Configdb volume size | `1Gi` |

#### Security

| Parameter | Description | Default |
|-----------|-------------|---------|
| `secret.jwtSecret` | JWT secret for UI auth | (placeholder) |
| `config.uiAuth` | Enable UI authentication | `true` |

## NBI API Usage

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

## Helm Commands

### Upgrade Release

```bash
# Update API key
helm upgrade genieacs ./examples/nbi-auth/helm/genieacs \
  --namespace genieacs \
  --set nbiAuth.apiKey="new-api-key-here"
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

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GenieACS Pod                              │
│  ┌─────────────────┐    ┌─────────────────────────────────────┐ │
│  │  Nginx Sidecar  │    │           GenieACS                  │ │
│  │    (7558)       │    │                                     │ │
│  │       │         │    │  - CWMP (7547)                      │ │
│  │  X-API-Key ─────┼────│  - NBI  (7557) ← internal only     │ │
│  │  Validation     │    │  - FS   (7567)                      │ │
│  │       │         │    │  - UI   (3000)                      │ │
│  └───────┼─────────┘    └─────────────────────────────────────┘ │
│          │                                                       │
└──────────┼───────────────────────────────────────────────────────┘
           │
    ┌──────▼──────┐
    │  Service    │
    │  7557→7558  │  (External NBI routes to nginx proxy)
    └─────────────┘
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
        ├── configmap.yaml      # GenieACS config
        ├── secret.yaml         # GenieACS secrets
        ├── mongodb-secret.yaml # MongoDB authentication
        ├── nginx-configmap.yaml # Nginx NBI auth config
        ├── mongodb-pvc.yaml    # MongoDB storage
        ├── mongodb-deployment.yaml
        ├── mongodb-service.yaml
        ├── genieacs-pvc.yaml   # GenieACS storage
        ├── genieacs-deployment.yaml  # GenieACS + Nginx sidecar
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
kubectl logs -l app.kubernetes.io/instance=genieacs -n genieacs -c genieacs
kubectl logs -l app.kubernetes.io/instance=genieacs -n genieacs -c nginx-nbi-auth
```

### NBI returns 401

```bash
# Verify API key
helm get values genieacs -n genieacs | grep apiKey

# Check nginx config
kubectl get configmap -n genieacs -l app.kubernetes.io/component=nbi-auth -o yaml

# Check nginx logs
kubectl logs -l app.kubernetes.io/instance=genieacs -n genieacs -c nginx-nbi-auth
```

### MongoDB connection error

```bash
# Check MongoDB pod
kubectl get pods -l app.kubernetes.io/component=database -n genieacs

# Check MongoDB logs
kubectl logs -l app.kubernetes.io/component=database -n genieacs
```

## Security Features

- NBI API protected with X-API-Key authentication
- MongoDB requires authentication (enabled by default)
- Nginx sidecar runs in the same pod as GenieACS
- Internal NBI port (7557) not exposed to service
- Health check endpoint `/health` available without authentication
- Security context: `allowPrivilegeEscalation: false`

## Security Recommendations

1. **Generate secure API key**: `openssl rand -hex 32`
2. **Generate secure JWT secret**: `openssl rand -hex 32`
3. **Generate secure MongoDB password**: `openssl rand -base64 24`
4. **Use NetworkPolicy** to restrict access
5. **Enable TLS** with Ingress for production
6. **Regular key rotation** for API key, JWT secret, and MongoDB password