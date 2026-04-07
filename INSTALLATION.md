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
- [MongoDB Backup](#mongodb-backup)
- [TLS/Ingress with cert-manager](#tlsingress-with-cert-manager)

---

## Prerequisites

### Docker Compose
- Docker Engine 20.10+
- Docker Compose v2+
- 4GB RAM minimum (GenieACS ~1.5GB + MongoDB ~256MB)
- 10GB disk space

### Kubernetes / Helm
- Kubernetes cluster v1.25+
- kubectl configured
- Helm v3.16+ (for Helm deployments)
- Storage provisioner (for PVC)
- 4GB RAM minimum per node (GenieACS pod needs ~1.5GB, MongoDB ~256MB)

### Security Requirements

> **Important:** MongoDB authentication is **required** for all deployments. Never run MongoDB without authentication in production.

All deployments require:
- **JWT Secret**: For GenieACS UI authentication (`GENIEACS_UI_JWT_SECRET`)
- **MongoDB Credentials**: Username and password for database access
- **API Key** (optional): For NBI API authentication when using nbi-auth variant

Generate secure secrets:
```bash
# JWT Secret (hex format)
openssl rand -hex 32

# MongoDB Password (base64 format)
openssl rand -base64 24

# API Key (hex format)
openssl rand -hex 32
```

---

## ARM64 Deployment Notes

GenieACS Stack supports ARM64 (aarch64) platforms including:
- Apple Silicon (M1/M2/M3/M4) via Docker Desktop
- AWS Graviton instances
- Raspberry Pi 4/5 (64-bit OS required)

### Important Considerations

1. **MongoDB 8.0 on x86**: Requires AVX CPU instructions. Older AMD64 CPUs (pre-2011) may fail with `Illegal instruction`. This does not affect ARM64.

2. **ARMv7 (32-bit) is NOT supported**: Node.js 24 dropped official ARMv7 binaries. Use a 64-bit OS on Raspberry Pi.

3. **Apple Silicon Docker Desktop**: Ensure "Use Rosetta for x86/amd64 emulation" is disabled for native ARM performance. The GenieACS image is natively built for arm64.

4. **Build times**: Cross-platform builds via QEMU are slower (~2-5x). For fastest builds on ARM64, build natively on an ARM host or use `make buildx-load`.

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

# Generate secrets
JWT_SECRET=$(openssl rand -hex 32)
MONGO_PASSWORD=$(openssl rand -base64 24)

# Update .env file with secrets
# macOS:
sed -i '' "s/GENIEACS_UI_JWT_SECRET=.*/GENIEACS_UI_JWT_SECRET=$JWT_SECRET/" .env
sed -i '' "s/MONGO_INITDB_ROOT_PASSWORD=.*/MONGO_INITDB_ROOT_PASSWORD=$MONGO_PASSWORD/" .env
# Linux:
# sed -i "s/GENIEACS_UI_JWT_SECRET=.*/GENIEACS_UI_JWT_SECRET=$JWT_SECRET/" .env
# sed -i "s/MONGO_INITDB_ROOT_PASSWORD=.*/MONGO_INITDB_ROOT_PASSWORD=$MONGO_PASSWORD/" .env

# IMPORTANT: Save these values securely!
echo "JWT_SECRET: $JWT_SECRET"
echo "MONGO_PASSWORD: $MONGO_PASSWORD"

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
MONGO_PASSWORD=$(openssl rand -base64 24)

# Update .env file
# macOS:
sed -i '' "s/GENIEACS_UI_JWT_SECRET=.*/GENIEACS_UI_JWT_SECRET=$JWT_SECRET/" .env
sed -i '' "s/GENIEACS_NBI_API_KEY=.*/GENIEACS_NBI_API_KEY=$API_KEY/" .env
sed -i '' "s/MONGO_INITDB_ROOT_PASSWORD=.*/MONGO_INITDB_ROOT_PASSWORD=$MONGO_PASSWORD/" .env
# Linux:
# sed -i "s/GENIEACS_UI_JWT_SECRET=.*/GENIEACS_UI_JWT_SECRET=$JWT_SECRET/" .env
# sed -i "s/GENIEACS_NBI_API_KEY=.*/GENIEACS_NBI_API_KEY=$API_KEY/" .env
# sed -i "s/MONGO_INITDB_ROOT_PASSWORD=.*/MONGO_INITDB_ROOT_PASSWORD=$MONGO_PASSWORD/" .env

# IMPORTANT: Save these values securely!
echo "JWT_SECRET: $JWT_SECRET"
echo "NBI API Key: $API_KEY"
echo "MONGO_PASSWORD: $MONGO_PASSWORD"

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

Each variant has a self-contained Kustomize directory with all resources and a `kustomization.yaml`:

```
examples/default/kubernetes/    # Standard deployment
examples/nbi-auth/kubernetes/   # With NBI API key authentication
```

### K8s Default

```bash
cd examples/default/kubernetes

# Generate secrets
JWT_SECRET=$(openssl rand -hex 32)
MONGO_PASSWORD=$(openssl rand -hex 16)

# Update secrets
# macOS:
sed -i '' "s/GENIEACS_UI_JWT_SECRET: .*/GENIEACS_UI_JWT_SECRET: \"$JWT_SECRET\"/" secret.yaml
sed -i '' "s/MONGO_INITDB_ROOT_PASSWORD: .*/MONGO_INITDB_ROOT_PASSWORD: \"$MONGO_PASSWORD\"/" mongodb-secret.yaml
# Linux:
# sed -i "s/GENIEACS_UI_JWT_SECRET: .*/GENIEACS_UI_JWT_SECRET: \"$JWT_SECRET\"/" secret.yaml
# sed -i "s/MONGO_INITDB_ROOT_PASSWORD: .*/MONGO_INITDB_ROOT_PASSWORD: \"$MONGO_PASSWORD\"/" mongodb-secret.yaml

# Update configmap with MongoDB credentials
# macOS:
sed -i '' "s|mongodb://admin:REPLACE_ME--openssl-rand-base64-24@|mongodb://admin:$MONGO_PASSWORD@|" configmap.yaml
# Linux:
# sed -i "s|mongodb://admin:REPLACE_ME--openssl-rand-base64-24@|mongodb://admin:$MONGO_PASSWORD@|" configmap.yaml

# IMPORTANT: Save these values securely!
echo "JWT_SECRET: $JWT_SECRET"
echo "MONGO_PASSWORD: $MONGO_PASSWORD"

# Deploy
kubectl apply -k .

# Wait for pods
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=genieacs \
  -n genieacs --timeout=300s

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
cd examples/nbi-auth/kubernetes

# Generate secrets
JWT_SECRET=$(openssl rand -hex 32)
API_KEY=$(openssl rand -hex 32)
MONGO_PASSWORD=$(openssl rand -hex 16)

# Update secrets
# macOS:
sed -i '' "s/GENIEACS_UI_JWT_SECRET: .*/GENIEACS_UI_JWT_SECRET: \"$JWT_SECRET\"/" secret.yaml
sed -i '' "s/MONGO_INITDB_ROOT_PASSWORD: .*/MONGO_INITDB_ROOT_PASSWORD: \"$MONGO_PASSWORD\"/" mongodb-secret.yaml
# Linux:
# sed -i "s/GENIEACS_UI_JWT_SECRET: .*/GENIEACS_UI_JWT_SECRET: \"$JWT_SECRET\"/" secret.yaml
# sed -i "s/MONGO_INITDB_ROOT_PASSWORD: .*/MONGO_INITDB_ROOT_PASSWORD: \"$MONGO_PASSWORD\"/" mongodb-secret.yaml

# Update configmap with MongoDB credentials
# macOS:
sed -i '' "s|mongodb://admin:REPLACE_ME--openssl-rand-base64-24@|mongodb://admin:$MONGO_PASSWORD@|" configmap.yaml
# Linux:
# sed -i "s|mongodb://admin:REPLACE_ME--openssl-rand-base64-24@|mongodb://admin:$MONGO_PASSWORD@|" configmap.yaml

# Update nginx NBI auth config with API key
# macOS:
sed -i '' "s/REPLACE_ME--openssl-rand-hex-32/$API_KEY/" nginx-nbi-auth.yaml
# Linux:
# sed -i "s/REPLACE_ME--openssl-rand-hex-32/$API_KEY/" nginx-nbi-auth.yaml

# IMPORTANT: Save these values securely!
echo "JWT_SECRET: $JWT_SECRET"
echo "NBI API Key: $API_KEY"
echo "MONGO_PASSWORD: $MONGO_PASSWORD"

# Deploy
kubectl apply -k .

# Wait for pods
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=genieacs \
  -n genieacs --timeout=300s

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
genieacs/genieacs          0.3.0          1.2.16       GenieACS - Open Source TR-069 Remote Management
genieacs/genieacs-nbi-auth 0.3.0          1.2.16       GenieACS with NBI API Key Authentication
```

### Helm Default

```bash
# Basic installation with secure secrets (recommended)
helm install genieacs genieacs/genieacs \
  --namespace genieacs \
  --create-namespace \
  --set secret.jwtSecret="$(openssl rand -hex 32)" \
  --set mongodb.auth.rootPassword="$(openssl rand -base64 24)"

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
  auth:
    enabled: true
    rootUsername: "admin"
    rootPassword: "your-secure-mongodb-password"
    # Or use existing secret (recommended for production)
    # existingSecret: "my-mongodb-secret"
  persistence:
    data:
      size: 20Gi
```

> **Note:** When using `existingSecret`, the secret must contain the key `GENIEACS_UI_JWT_SECRET`.

#### Verify Installation

Run Helm tests to verify connectivity:
```bash
helm test genieacs -n genieacs
```
This verifies GenieACS UI, NBI API, and MongoDB connectivity.

### Helm NBI Auth

```bash
# Basic installation with generated secrets
helm install genieacs genieacs/genieacs-nbi-auth \
  --namespace genieacs \
  --create-namespace \
  --set nbiAuth.apiKey="$(openssl rand -hex 32)" \
  --set secret.jwtSecret="$(openssl rand -hex 32)" \
  --set mongodb.auth.rootPassword="$(openssl rand -base64 24)"

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
  auth:
    enabled: true
    rootUsername: "admin"
    rootPassword: "your-secure-mongodb-password"
    # Or use existing secret (recommended for production)
    # existingSecret: "my-mongodb-secret"
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

#### Verify Installation

Run Helm tests to verify connectivity:
```bash
helm test genieacs -n genieacs
```
This verifies GenieACS UI, NBI API, and MongoDB connectivity.

### Helm Commands Reference

```bash
# List releases
helm list -n genieacs

# Get release status
helm status genieacs -n genieacs

# Get configured values
helm get values genieacs -n genieacs

# Upgrade release
helm upgrade genieacs genieacs/genieacs -n genieacs --set genieacs.image.tag=1.2.16

# Rollback
helm rollback genieacs -n genieacs

# Uninstall
helm uninstall genieacs -n genieacs
```

---

## ArgoCD (GitOps)

For GitOps deployment using ArgoCD with manual sync (recommended for production). ArgoCD applications reference the published Helm charts and configure them with production-ready defaults.

> **Note:** ArgoCD deployment requires ArgoCD to be installed on your cluster. The provided Application manifests are pre-configured with memory limits (2Gi), existingSecret support, and manual sync policy. See [examples/argocd/README.md](examples/argocd/README.md) for detailed configuration.

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
  --revision 0.3.0 \
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

#### Docker (using Make)
```bash
cd /path/to/genieacs-stack
make create-user
```

This reads `GENIEACS_ADMIN_USERNAME` and `GENIEACS_ADMIN_PASSWORD` from `.env` and performs the full setup:

1. Hashes the password with PBKDF2-SHA512 and inserts the user into MongoDB
2. Creates admin permissions (30 entries) so the user can access all pages
3. On fresh installs, bootstraps default config (presets, provisions, overview layout)
4. Invalidates the GenieACS internal cache so login works immediately

After running this command, you can log in and see the full dashboard right away.

#### Docker (custom credentials)
```bash
./scripts/create-user.sh myuser mypassword admin
```

Roles: `admin`, `readwrite`, `readonly`.

#### Kubernetes / Helm
```bash
# Get pod name
POD=$(kubectl get pods -n genieacs -l app.kubernetes.io/name=genieacs -o jsonpath='{.items[0].metadata.name}')
MONGO_POD=$(kubectl get pods -n genieacs -l app.kubernetes.io/name=mongodb -o jsonpath='{.items[0].metadata.name}')

# Generate hash inside the GenieACS pod
HASH_JSON=$(kubectl exec $POD -n genieacs -- node -e "
const crypto = require('crypto');
const salt = crypto.randomBytes(64).toString('hex');
const hash = crypto.pbkdf2Sync('yourpassword', salt, 10000, 128, 'sha512').toString('hex');
console.log(JSON.stringify({_id:'admin',password:hash,salt:salt,roles:'admin'}));
")

# Insert into MongoDB (replace YOUR_MONGO_PASSWORD)
echo "$HASH_JSON" | kubectl exec -i $MONGO_POD -n genieacs -- \
  mongosh --quiet "mongodb://admin:YOUR_MONGO_PASSWORD@localhost:27017/genieacs?authSource=admin" \
  --eval 'db.users.insertOne(JSON.parse(require("fs").readFileSync("/dev/stdin","utf8")))'

# Invalidate cache so login works immediately
kubectl exec $MONGO_POD -n genieacs -- \
  mongosh --quiet "mongodb://admin:YOUR_MONGO_PASSWORD@localhost:27017/genieacs?authSource=admin" \
  --eval 'db.cache.deleteOne({_id: "ui-local-cache-hash"})'
```

> **Note:** After inserting users directly into MongoDB, you must invalidate the `ui-local-cache-hash` entry in the `cache` collection. GenieACS caches user data and won't see new users until the cache refreshes (up to 5 seconds after invalidation).

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

## MongoDB Backup

Enable automated MongoDB backups via the Helm chart's built-in CronJob support.

### Enable Backup CronJob

```bash
helm install genieacs genieacs/genieacs \
  --namespace genieacs \
  --create-namespace \
  --set backup.enabled=true \
  --set backup.schedule="0 2 * * *" \
  --set backup.retention=7
```

This creates a Kubernetes CronJob that runs `mongodump` daily at 2:00 AM and retains the last 7 backups.

### Check Backup Status

```bash
kubectl get cronjob -n genieacs
```

### Trigger a Manual Backup

```bash
kubectl create job --from=cronjob/<backup-cronjob-name> manual-backup -n genieacs
```

Replace `<backup-cronjob-name>` with the actual CronJob name shown in `kubectl get cronjob` output.

---

## TLS/Ingress with cert-manager

Enable TLS-terminated Ingress using cert-manager for automatic certificate provisioning.

### Prerequisites

- An Ingress controller installed (e.g., ingress-nginx)
- cert-manager installed with a configured `ClusterIssuer` (e.g., `letsencrypt-prod`)

### Enable Ingress with TLS

```bash
helm install genieacs genieacs/genieacs \
  --namespace genieacs \
  --create-namespace \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set 'ingress.annotations.cert-manager\.io/cluster-issuer=letsencrypt-prod' \
  --set 'ingress.hosts[0].host=genieacs.example.com' \
  --set 'ingress.hosts[0].paths[0].path=/' \
  --set 'ingress.hosts[0].paths[0].pathType=Prefix' \
  --set 'ingress.hosts[0].paths[0].port=3000' \
  --set 'ingress.tls[0].secretName=genieacs-tls' \
  --set 'ingress.tls[0].hosts[0]=genieacs.example.com'
```

Replace `genieacs.example.com` with your actual domain. The `port=3000` routes traffic to the GenieACS Web UI. To expose additional services (NBI API, CWMP, File Server), add more path entries or create separate Ingress resources.

### Verify Certificate

```bash
# Check Ingress resource
kubectl get ingress -n genieacs

# Check certificate status
kubectl get certificate -n genieacs

# Verify TLS is working
curl -v https://genieacs.example.com/
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

**MongoDB authentication failed:**
```bash
# Check if MongoDB secret exists
kubectl get secret mongodb-secret -n genieacs

# Verify secret values
kubectl get secret mongodb-secret -n genieacs -o jsonpath='{.data.MONGO_INITDB_ROOT_USERNAME}' | base64 -d
kubectl get secret mongodb-secret -n genieacs -o jsonpath='{.data.MONGO_INITDB_ROOT_PASSWORD}' | base64 -d

# Check MongoDB logs for auth errors
kubectl logs -l app.kubernetes.io/name=mongodb -n genieacs | grep -i "auth"

# Verify connection URL in configmap matches credentials
kubectl get configmap genieacs-config -n genieacs -o yaml | grep MONGODB_CONNECTION_URL
```

**Docker MongoDB authentication failed:**
```bash
# Check MongoDB logs
docker compose logs mongo

# Verify environment variables
docker compose exec genieacs env | grep MONGO

# Test MongoDB connection manually
docker compose exec mongo mongosh -u admin -p YOUR_PASSWORD --authenticationDatabase admin
```

**Login fails after creating user ("Incorrect username or password"):**
```bash
# GenieACS caches user data internally. If you inserted users directly
# into MongoDB (not via the create-user.sh script), clear the cache:
docker exec mongo-genieacs mongosh --quiet \
  "mongodb://admin:YOUR_MONGO_PASSWORD@localhost:27017/genieacs?authSource=admin" \
  --eval 'db.cache.deleteOne({_id: "ui-local-cache-hash"})'

# The user should be loginable within ~5 seconds after cache invalidation.
# The create-user.sh script handles this automatically.
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

**Secret not found errors:**
```bash
# List all secrets in namespace
kubectl get secrets -n genieacs

# Check if required secrets exist
kubectl get secret genieacs-secret -n genieacs
kubectl get secret mongodb-secret -n genieacs

# Create missing secrets (see instructions above)
```

---

## Next Steps

- Read [SECURITY.md](SECURITY.md) for security best practices
- Store all generated secrets securely (password manager recommended)
- Configure CPE devices to connect to CWMP endpoint
- Set up monitoring and alerting
- Configure backups for MongoDB data
- Consider using Kubernetes Secrets or Sealed Secrets for production deployments

---

## Useful Links

- [GenieACS Documentation](https://docs.genieacs.com/)
- [GitHub Repository](https://github.com/Cepat-Kilat-Teknologi/genieacs-stack)
- [Docker Hub](https://hub.docker.com/r/cepatkilatteknologi/genieacs)
- [Helm Charts](https://cepat-kilat-teknologi.github.io/genieacs-stack)