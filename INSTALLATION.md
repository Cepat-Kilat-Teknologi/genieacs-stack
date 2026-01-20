# Installation Guide

Complete installation guide for GenieACS Stack. Choose the deployment method that best fits your environment.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Comparison](#quick-comparison)
- [Docker Compose](#docker-compose)
  - [Default Deployment](#docker-default)
  - [With NBI Authentication](#docker-nbi-auth)
- [Kubernetes (Kustomize)](#kubernetes-kustomize)
  - [Default Deployment](#k8s-default)
  - [With NBI Authentication](#k8s-nbi-auth)
- [Helm Charts](#helm-charts)
  - [Default Deployment](#helm-default)
  - [With NBI Authentication](#helm-nbi-auth)
- [ArgoCD (GitOps)](#argocd-gitops)
- [Post-Installation](#post-installation)
- [Verification](#verification)

---

## Prerequisites

### Docker Compose
- Docker Engine 20.10+
- Docker Compose v2+
- 2GB RAM minimum
- 10GB disk space

### Kubernetes / Helm
- Kubernetes cluster v1.25+
- kubectl configured
- Helm v3.10+ (for Helm deployments)
- Storage provisioner (for PVC)

---

## Quick Comparison

| Method | Best For | Complexity | Scalability |
|--------|----------|------------|-------------|
| Docker Compose | Development, Small deployments | Low | Limited |
| Kubernetes (Kustomize) | Production, Custom configurations | Medium | High |
| Helm | Production, Standardized deployments | Low | High |
| ArgoCD | Production, GitOps workflows | Medium | High |

---

## Docker Compose

### Docker Default

Basic deployment without NBI API authentication.

```bash
# Navigate to directory
cd examples/default/docker

# Create environment file
cp .env.example .env

# Generate and set JWT secret
JWT_SECRET=$(openssl rand -hex 32)
sed -i '' "s/GENIEACS_UI_JWT_SECRET=.*/GENIEACS_UI_JWT_SECRET=$JWT_SECRET/" .env

# Start services
docker compose up -d

# Verify deployment
docker compose ps
```

**Access Points:**
| Service | URL |
|---------|-----|
| Web UI | http://localhost:3000 |
| CWMP | http://localhost:7547 |
| NBI API | http://localhost:7557 |
| File Server | http://localhost:7567 |

### Docker NBI Auth

Deployment with X-API-Key authentication for NBI API.

```bash
# Navigate to directory
cd examples/nbi-auth/docker

# Create environment file
cp .env.example .env

# Generate secrets
JWT_SECRET=$(openssl rand -hex 32)
API_KEY=$(openssl rand -hex 32)

# Update .env file
sed -i '' "s/GENIEACS_UI_JWT_SECRET=.*/GENIEACS_UI_JWT_SECRET=$JWT_SECRET/" .env
sed -i '' "s/GENIEACS_NBI_API_KEY=.*/GENIEACS_NBI_API_KEY=$API_KEY/" .env

# Display your API key (save this!)
echo "Your NBI API Key: $API_KEY"

# Start services
docker compose up -d

# Verify deployment
docker compose ps
```

**Testing NBI Authentication:**
```bash
# Without API key (returns 401)
curl http://localhost:7557/devices

# With API key (returns 200)
curl -H "X-API-Key: YOUR_API_KEY" http://localhost:7557/devices

# Health check (no auth required)
curl http://localhost:7557/health
```

---

## Kubernetes (Kustomize)

### K8s Default

```bash
# Navigate to directory
cd examples/default/kubernetes

# Generate JWT secret
JWT_SECRET=$(openssl rand -hex 32)

# Update secret.yaml
sed -i '' "s/GENIEACS_UI_JWT_SECRET: .*/GENIEACS_UI_JWT_SECRET: \"$JWT_SECRET\"/" secret.yaml

# Deploy
kubectl apply -k .

# Wait for pods
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=genieacs \
  -n genieacs --timeout=180s

# Verify
kubectl get all -n genieacs
```

**Access via Port Forward:**
```bash
kubectl port-forward svc/genieacs -n genieacs \
  3000:3000 7547:7547 7557:7557 7567:7567
```

### K8s NBI Auth

```bash
# Navigate to directory
cd examples/nbi-auth/kubernetes

# Generate secrets
JWT_SECRET=$(openssl rand -hex 32)
API_KEY=$(openssl rand -hex 32)

# Update secret.yaml
sed -i '' "s/GENIEACS_UI_JWT_SECRET: .*/GENIEACS_UI_JWT_SECRET: \"$JWT_SECRET\"/" secret.yaml

# Update nginx-nbi-auth.yaml (replace the API key in the if statement)
sed -i '' "s/changeme-generate-with-openssl-rand-hex-32/$API_KEY/" nginx-nbi-auth.yaml

# Display your API key (save this!)
echo "Your NBI API Key: $API_KEY"

# Deploy
kubectl apply -k .

# Wait for pods
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=genieacs \
  -n genieacs --timeout=180s

# Verify
kubectl get all -n genieacs
```

---

## Helm Charts

### Add Helm Repository

```bash
helm repo add genieacs https://cepat-kilat-teknologi.github.io/genieacs-stack
helm repo update
```

### Search Available Charts

```bash
helm search repo genieacs
```

Output:
```
NAME                       CHART VERSION  APP VERSION  DESCRIPTION
genieacs/genieacs          0.2.0          1.2.13       GenieACS - Open Source TR-069 Remote Management
genieacs/genieacs-nbi-auth 0.2.0          1.2.13       GenieACS with NBI API Key Authentication
```

### Helm Default

```bash
# Basic installation
helm install genieacs genieacs/genieacs \
  --namespace genieacs \
  --create-namespace

# With custom JWT secret (recommended)
helm install genieacs genieacs/genieacs \
  --namespace genieacs \
  --create-namespace \
  --set secret.jwtSecret="$(openssl rand -hex 32)"

# With existing Kubernetes secret (production recommended)
# First create the secret:
kubectl create namespace genieacs
kubectl create secret generic my-genieacs-secret \
  --namespace genieacs \
  --from-literal=GENIEACS_UI_JWT_SECRET="$(openssl rand -hex 32)"

# Then install with existingSecret:
helm install genieacs genieacs/genieacs \
  --namespace genieacs \
  --set secret.existingSecret=my-genieacs-secret

# With custom values file
helm install genieacs genieacs/genieacs \
  --namespace genieacs \
  --create-namespace \
  -f my-values.yaml
```

**Example values file (my-values.yaml):**
```yaml
secret:
  # Option 1: Provide JWT secret directly (not recommended for production)
  jwtSecret: "your-secure-jwt-secret-here"

  # Option 2: Use existing Kubernetes secret (recommended for production)
  # existingSecret: "my-genieacs-secret"

genieacs:
  replicaCount: 1
  service:
    type: LoadBalancer
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
```

> **Note:** When using `existingSecret`, the secret must contain the key `GENIEACS_UI_JWT_SECRET`.

### Helm NBI Auth

```bash
# Basic installation with generated secrets
helm install genieacs genieacs/genieacs-nbi-auth \
  --namespace genieacs \
  --create-namespace \
  --set nbiAuth.apiKey="$(openssl rand -hex 32)" \
  --set secret.jwtSecret="$(openssl rand -hex 32)"

# With existing Kubernetes secret for JWT (production recommended)
# First create the secret:
kubectl create namespace genieacs
kubectl create secret generic my-genieacs-secret \
  --namespace genieacs \
  --from-literal=GENIEACS_UI_JWT_SECRET="$(openssl rand -hex 32)"

# Then install with existingSecret:
helm install genieacs genieacs/genieacs-nbi-auth \
  --namespace genieacs \
  --set secret.existingSecret=my-genieacs-secret \
  --set nbiAuth.apiKey="$(openssl rand -hex 32)"

# Display configured API key
helm get values genieacs -n genieacs | grep apiKey
```

**Example values file for NBI Auth (my-values-nbi.yaml):**
```yaml
nbiAuth:
  enabled: true
  apiKey: "your-secure-api-key-here"

secret:
  # Option 1: Provide JWT secret directly
  jwtSecret: "your-secure-jwt-secret-here"

  # Option 2: Use existing Kubernetes secret (recommended for production)
  # existingSecret: "my-genieacs-secret"

genieacs:
  service:
    type: LoadBalancer
  resources:
    requests:
      cpu: "500m"
      memory: "512Mi"

mongodb:
  persistence:
    data:
      size: 20Gi
```

```bash
helm install genieacs genieacs/genieacs-nbi-auth \
  --namespace genieacs \
  --create-namespace \
  -f my-values-nbi.yaml
```

> **Note:** The `nbiAuth.apiKey` is embedded in nginx ConfigMap. For JWT secret, use `existingSecret` in production.

### Helm Commands Reference

```bash
# List releases
helm list -n genieacs

# Get release status
helm status genieacs -n genieacs

# Get configured values
helm get values genieacs -n genieacs

# Upgrade release
helm upgrade genieacs genieacs/genieacs -n genieacs --set genieacs.image.tag=1.2.14

# Rollback
helm rollback genieacs -n genieacs

# Uninstall
helm uninstall genieacs -n genieacs
```

---

## ArgoCD (GitOps)

For GitOps deployment using ArgoCD with manual sync (recommended for production).

### Prerequisites

- ArgoCD installed on your cluster
- kubectl access to the cluster

### Deploy with ArgoCD

```bash
# Using the provided Application manifest
kubectl apply -f examples/argocd/genieacs-nbi-auth-app.yaml

# Or create directly via ArgoCD CLI
argocd app create genieacs \
  --repo https://cepat-kilat-teknologi.github.io/genieacs-stack \
  --helm-chart genieacs-nbi-auth \
  --revision 0.2.0 \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace genieacs \
  --sync-option CreateNamespace=true
```

### Manual Sync

```bash
# Sync via CLI
argocd app sync genieacs

# Or via ArgoCD UI:
# 1. Open ArgoCD Dashboard
# 2. Find "genieacs" application
# 3. Click "Sync" button
```

> **Important:** Before deploying, update the secrets in the Application manifest. See [examples/argocd/README.md](examples/argocd/README.md) for detailed configuration.

---

## Post-Installation

### Create Admin User

#### Docker
```bash
cd /path/to/genieacs-stack
./scripts/create-user.sh admin yourpassword admin
```

#### Kubernetes / Helm
```bash
# Get pod name
POD=$(kubectl get pods -n genieacs -l app.kubernetes.io/name=genieacs -o jsonpath='{.items[0].metadata.name}')

# Enter pod
kubectl exec -it $POD -n genieacs -- /bin/bash

# Create user (inside pod)
cd /opt/genieacs
node -e "
const crypto = require('crypto');
const salt = crypto.randomBytes(64).toString('hex');
const hash = crypto.pbkdf2Sync('yourpassword', salt, 10000, 128, 'sha512').toString('hex');
console.log(JSON.stringify({_id:'admin',password:hash,salt:salt,roles:'admin'}));
" | mongosh mongodb:27017/genieacs --eval 'db.users.insertOne(JSON.parse(require("fs").readFileSync("/dev/stdin","utf8")))'
```

---

## Verification

### Test Endpoints

```bash
# Web UI
curl -s -o /dev/null -w "UI: %{http_code}\n" http://localhost:3000/

# NBI API
curl -s http://localhost:7557/devices

# NBI API with auth (if using nbi-auth)
curl -s -H "X-API-Key: YOUR_API_KEY" http://localhost:7557/devices

# CWMP (expects 405 - only accepts POST from CPE)
curl -s -o /dev/null -w "CWMP: %{http_code}\n" http://localhost:7547/

# File Server
curl -s -o /dev/null -w "FS: %{http_code}\n" http://localhost:7567/
```

### Check Logs

#### Docker
```bash
docker compose logs -f genieacs
```

#### Kubernetes / Helm
```bash
kubectl logs -f -l app.kubernetes.io/name=genieacs -n genieacs
```

---

## Troubleshooting

### Common Issues

**Pods not starting:**
```bash
kubectl describe pod -l app.kubernetes.io/name=genieacs -n genieacs
kubectl get events -n genieacs --sort-by='.lastTimestamp'
```

**MongoDB connection error:**
```bash
# Check MongoDB pod
kubectl logs -l app.kubernetes.io/name=mongodb -n genieacs

# Test connection
kubectl exec -it deployment/genieacs -n genieacs -- nc -zv mongodb 27017
```

**NBI returns 401:**
```bash
# Check API key configuration
helm get values genieacs -n genieacs | grep apiKey

# Check nginx logs (nbi-auth only)
kubectl logs -l app.kubernetes.io/name=genieacs -n genieacs -c nginx-nbi-auth
```

**PVC Pending:**
```bash
kubectl get pvc -n genieacs
kubectl get storageclass
```

---

## Next Steps

- Read [SECURITY.md](SECURITY.md) for security best practices
- Configure CPE devices to connect to CWMP endpoint
- Set up monitoring and alerting
- Configure backups for MongoDB data

---

## Useful Links

- [GenieACS Documentation](https://docs.genieacs.com/)
- [GitHub Repository](https://github.com/Cepat-Kilat-Teknologi/genieacs-stack)
- [Docker Hub](https://hub.docker.com/r/cepatkilatteknologi/genieacs)
- [Helm Charts](https://cepat-kilat-teknologi.github.io/genieacs-stack)