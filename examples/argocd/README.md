# ArgoCD Deployment

Deploy GenieACS to Kubernetes using ArgoCD with manual sync for production environments.

## Prerequisites

- ArgoCD installed on your cluster
- kubectl configured to access your cluster
- ArgoCD CLI (optional, for command-line operations)

## Available Applications

| Application | Chart | Description |
|-------------|-------|-------------|
| `genieacs-app.yaml` | genieacs | Default deployment without NBI auth |
| `genieacs-nbi-auth-app.yaml` | genieacs-nbi-auth | With NBI API authentication |

## Quick Start

### 1. Configure Secrets

Before deploying, update the secrets in the application manifest:

```bash
# Generate secrets
JWT_SECRET=$(openssl rand -hex 32)
API_KEY=$(openssl rand -hex 32)  # Only for nbi-auth

echo "JWT Secret: $JWT_SECRET"
echo "API Key: $API_KEY"
```

Edit the YAML file and replace the placeholder values:
- `jwtSecret: "changeme-generate-with-openssl-rand-hex-32"`
- `apiKey: "changeme-generate-with-openssl-rand-hex-32"` (nbi-auth only)

### 2. Configure Destination Cluster

Update the `destination.server` in the YAML file to point to your production cluster:

```yaml
destination:
  # For in-cluster deployment
  server: https://kubernetes.default.svc

  # Or for external cluster (add cluster to ArgoCD first)
  # server: https://your-production-cluster-api:6443
  namespace: genieacs
```

### 3. Deploy Application

**Option A: Using kubectl**

```bash
# Deploy default version
kubectl apply -f genieacs-app.yaml

# Or deploy with NBI auth
kubectl apply -f genieacs-nbi-auth-app.yaml
```

**Option B: Using ArgoCD CLI**

```bash
# Login to ArgoCD
argocd login <ARGOCD_SERVER>

# Create application from file
argocd app create -f genieacs-app.yaml

# Or create application directly
argocd app create genieacs \
  --repo https://cepat-kilat-teknologi.github.io/genieacs-stack \
  --helm-chart genieacs \
  --revision 0.2.0 \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace genieacs \
  --sync-option CreateNamespace=true
```

### 4. Manual Sync

Since this is production, sync is manual. To sync:

**Via ArgoCD UI:**
1. Open ArgoCD dashboard
2. Find the `genieacs` application
3. Click "Sync" button
4. Review changes and confirm

**Via ArgoCD CLI:**
```bash
# Sync application
argocd app sync genieacs

# Sync with prune (remove deleted resources)
argocd app sync genieacs --prune

# Check sync status
argocd app get genieacs
```

**Via kubectl:**
```bash
# Trigger sync by adding annotation
kubectl -n argocd patch application genieacs \
  --type merge \
  -p '{"metadata": {"annotations": {"argocd.argoproj.io/refresh": "hard"}}}'
```

## Configuration Options

### Using External Cluster

First, add your production cluster to ArgoCD:

```bash
# Add cluster
argocd cluster add your-production-context

# List clusters
argocd cluster list
```

Then update `destination.server` in the YAML.

### Using Different Values

You can override Helm values in the Application manifest:

```yaml
spec:
  source:
    helm:
      values: |
        genieacs:
          replicaCount: 2
          service:
            type: ClusterIP
            loadBalancerIP: "10.0.0.100"
        mongodb:
          persistence:
            data:
              size: 50Gi
              storageClassName: "fast-ssd"
```

### Using Sealed Secrets

For production, use Sealed Secrets or external secret management:

```yaml
spec:
  source:
    helm:
      values: |
        secret:
          existingSecret: "genieacs-secrets"  # Pre-created secret
```

Create the secret separately:
```bash
kubectl create secret generic genieacs-secrets \
  --from-literal=GENIEACS_UI_JWT_SECRET=$(openssl rand -hex 32) \
  -n genieacs
```

## Sync Policies

### Manual Sync (Default - Recommended for Production)

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
```

### Auto Sync (For non-production)

```yaml
syncPolicy:
  automated:
    prune: true      # Remove resources not in Git
    selfHeal: true   # Revert manual changes
  syncOptions:
    - CreateNamespace=true
```

## Monitoring

### Check Application Status

```bash
# List all applications
argocd app list

# Get detailed status
argocd app get genieacs

# Watch sync status
argocd app get genieacs --refresh
```

### View Resources

```bash
# List managed resources
argocd app resources genieacs

# View resource tree
argocd app tree genieacs
```

### View Logs

```bash
# Application logs
argocd app logs genieacs

# Pod logs via kubectl
kubectl logs -l app.kubernetes.io/name=genieacs -n genieacs -f
```

## Rollback

```bash
# View history
argocd app history genieacs

# Rollback to previous version
argocd app rollback genieacs <REVISION>

# Or rollback to specific revision
argocd app rollback genieacs 2
```

## Troubleshooting

### Application Out of Sync

```bash
# Check diff
argocd app diff genieacs

# Force sync
argocd app sync genieacs --force
```

### Sync Failed

```bash
# Check application events
kubectl describe application genieacs -n argocd

# Check ArgoCD logs
kubectl logs -l app.kubernetes.io/name=argocd-application-controller -n argocd
```

### Health Check Failed

```bash
# Check pod status
kubectl get pods -n genieacs

# Check pod events
kubectl describe pod -l app.kubernetes.io/name=genieacs -n genieacs
```

## Uninstall

```bash
# Delete application (keeps resources)
argocd app delete genieacs

# Delete application and resources
argocd app delete genieacs --cascade

# Or via kubectl
kubectl delete application genieacs -n argocd
```