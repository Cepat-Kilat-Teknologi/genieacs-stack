# Security Guide

Security best practices and configurations for GenieACS Stack deployments.

## Table of Contents

- [Overview](#overview)
- [Authentication](#authentication)
  - [Web UI Authentication](#web-ui-authentication)
  - [NBI API Authentication](#nbi-api-authentication)
  - [MongoDB Authentication](#mongodb-authentication)
- [Secrets Management](#secrets-management)
- [Network Security](#network-security)
- [Container Security](#container-security)
- [Production Checklist](#production-checklist)
- [Security Updates](#security-updates)
- [Reporting Vulnerabilities](#reporting-vulnerabilities)

---

## Overview

GenieACS Stack includes several security features:

| Feature | Description |
|---------|-------------|
| JWT Authentication | Web UI protected with JWT tokens |
| NBI API Key Auth | Optional X-API-Key header authentication |
| MongoDB Authentication | Database access requires username/password |
| Non-root Processes | Containers run as non-root where possible |
| Security Contexts | `allowPrivilegeEscalation: false` enabled |
| No Default Credentials | All secrets must be configured before deployment |
| Internal MongoDB | Database not exposed externally by default |

---

## Authentication

### Web UI Authentication

The Web UI uses JWT (JSON Web Token) for authentication.

**Configuration:**

```bash
# Generate secure JWT secret (minimum 32 characters)
openssl rand -hex 32
```

**Docker (.env):**
```env
GENIEACS_UI_JWT_SECRET=your-generated-secret-here
GENIEACS_UI_AUTH=true
```

**Kubernetes (secret.yaml):**
```yaml
stringData:
  GENIEACS_UI_JWT_SECRET: "your-generated-secret-here"
```

**Helm (values.yaml):**
```yaml
secret:
  jwtSecret: "your-generated-secret-here"
config:
  uiAuth: "true"
```

> **Warning:** Never use the default placeholder values in production. Always generate unique secrets.

### NBI API Authentication

GenieACS NBI API does not have native authentication. This stack provides optional X-API-Key authentication via Nginx reverse proxy.

**How it works:**

```
Client Request → Nginx (validates X-API-Key) → GenieACS NBI
```

**Architecture (nbi-auth deployments):**

```
┌─────────────────────────────────────────────────┐
│                   Pod                           │
│  ┌─────────────┐       ┌─────────────────────┐ │
│  │   Nginx     │       │     GenieACS        │ │
│  │   (7558)    │──────▶│     NBI (7557)      │ │
│  │ X-API-Key   │       │   (internal only)   │ │
│  │ Validation  │       │                     │ │
│  └─────────────┘       └─────────────────────┘ │
└─────────────────────────────────────────────────┘
         ▲
         │ External traffic (port 7557)
         │ requires X-API-Key header
```

**Using NBI API with authentication:**

```bash
# Generate API key
API_KEY=$(openssl rand -hex 32)
echo "Your API Key: $API_KEY"

# Request without API key (returns 401)
curl http://localhost:7557/devices
# {"error": "Invalid or missing X-API-Key"}

# Request with API key (returns 200)
curl -H "X-API-Key: $API_KEY" http://localhost:7557/devices

# Health check endpoint (no auth required)
curl http://localhost:7557/health
```

**Deployment options with NBI auth:**
- Docker: `examples/nbi-auth/docker/`
- Kubernetes: `examples/nbi-auth/kubernetes/`
- Helm: `genieacs/genieacs-nbi-auth`

### MongoDB Authentication

MongoDB is configured with authentication enabled by default in Kubernetes and Helm deployments.

**Configuration:**

```bash
# Generate secure MongoDB password
openssl rand -base64 24
```

**Kubernetes (mongodb-secret.yaml):**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-secret
  namespace: genieacs
type: Opaque
stringData:
  MONGO_INITDB_ROOT_USERNAME: "admin"
  MONGO_INITDB_ROOT_PASSWORD: "your-secure-password-here"
```

**Helm (values.yaml):**
```yaml
mongodb:
  auth:
    enabled: true
    rootUsername: "admin"
    rootPassword: "your-secure-password-here"
    # Or use existing secret (recommended for production)
    existingSecret: "my-mongodb-secret"
```

**Connection URL format:**
```
mongodb://username:password@mongodb:27017/genieacs?authSource=admin
```

> **Important:** When changing MongoDB credentials, update both `mongodb-secret.yaml` and the connection URL in `configmap.yaml` (or Helm values).

---

## Secrets Management

### Required Secrets

| Secret | Purpose | Generation |
|--------|---------|------------|
| JWT Secret | Web UI authentication | `openssl rand -hex 32` |
| NBI API Key | NBI API authentication (optional) | `openssl rand -hex 32` |
| MongoDB Password | Database authentication | `openssl rand -base64 24` |

### Using Existing Secrets (Recommended for Production)

The Helm charts support `existingSecret` to reference pre-created Kubernetes secrets instead of storing secrets in values.

**Step 1: Create the Kubernetes secret**
```bash
kubectl create namespace genieacs

kubectl create secret generic genieacs-secrets \
  --namespace genieacs \
  --from-literal=GENIEACS_UI_JWT_SECRET="$(openssl rand -hex 32)"
```

**Step 2: Reference in Helm values**
```yaml
secret:
  existingSecret: "genieacs-secrets"
```

**Step 3: Install with existingSecret**
```bash
helm install genieacs genieacs/genieacs \
  --namespace genieacs \
  --set secret.existingSecret=genieacs-secrets
```

> **Important:** When using `existingSecret`, the secret must contain the key `GENIEACS_UI_JWT_SECRET`.

### Best Practices

1. **Never commit secrets to version control**
   ```bash
   # .gitignore already includes
   .env
   .env.local
   .env.*.local
   ```

2. **Use environment-specific secrets**
   - Development: Local `.env` files or `--set secret.jwtSecret=...`
   - Production: Use `existingSecret` with Kubernetes Secrets, Sealed Secrets, or external secret managers

3. **Rotate secrets regularly**
   ```bash
   # Generate new secret
   NEW_SECRET=$(openssl rand -hex 32)

   # Update the Kubernetes secret
   kubectl create secret generic genieacs-secrets \
     --namespace genieacs \
     --from-literal=GENIEACS_UI_JWT_SECRET="$NEW_SECRET" \
     --dry-run=client -o yaml | kubectl apply -f -

   # Restart pods to pick up new secret
   kubectl rollout restart deployment/genieacs -n genieacs
   ```

4. **Use Kubernetes Secrets properly**
   ```bash
   # Create secret from literal
   kubectl create secret generic genieacs-secrets \
     --from-literal=GENIEACS_UI_JWT_SECRET=$(openssl rand -hex 32) \
     -n genieacs
   ```

### External Secret Management

For production, consider using:

- **HashiCorp Vault**
- **AWS Secrets Manager**
- **Azure Key Vault**
- **Google Secret Manager**
- **Kubernetes External Secrets Operator**

---

## Network Security

### Restrict Service Access

**Option 1: Bind to localhost (Docker)**

```env
# .env - Only accessible from host
GENIEACS_UI_PORT=127.0.0.1:3000
GENIEACS_CWMP_PORT=127.0.0.1:7547
GENIEACS_NBI_PORT=127.0.0.1:7557
GENIEACS_FS_PORT=127.0.0.1:7567
```

**Option 2: Use ClusterIP (Kubernetes)**

```yaml
# values.yaml
genieacs:
  service:
    type: ClusterIP  # Not exposed externally
```

Access via port-forward:
```bash
kubectl port-forward svc/genieacs -n genieacs 3000:3000
```

**Option 3: NetworkPolicy (Kubernetes)**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: genieacs-network-policy
  namespace: genieacs
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: genieacs
  policyTypes:
    - Ingress
  ingress:
    # Allow UI from anywhere
    - ports:
        - port: 3000
    # Allow CWMP from CPE network only
    - from:
        - ipBlock:
            cidr: 10.0.0.0/8  # Your CPE network
      ports:
        - port: 7547
    # Allow NBI from trusted namespace only
    - from:
        - namespaceSelector:
            matchLabels:
              name: trusted-apps
      ports:
        - port: 7557
```

### TLS/HTTPS

For production, use TLS termination:

**Option 1: Ingress with TLS**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: genieacs-ingress
  namespace: genieacs
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - genieacs.example.com
      secretName: genieacs-tls
  rules:
    - host: genieacs.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: genieacs
                port:
                  number: 3000
```

**Option 2: Reverse Proxy (Nginx/Traefik)**

Place a reverse proxy in front of GenieACS with TLS termination.

---

## Container Security

### Security Contexts

All deployments include security hardening:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false  # Required for GenieACS
  runAsNonRoot: false  # Some processes require root
```

### Docker Security Options

```yaml
# docker-compose.yml
services:
  genieacs:
    security_opt:
      - no-new-privileges:true
```

### Image Security

- Base image: `debian:bookworm-slim` (minimal attack surface)
- Regular security updates
- No unnecessary packages installed

**Scan images for vulnerabilities:**

```bash
# Using Docker Scout
docker scout cves cepatkilatteknologi/genieacs:1.2.13

# Using Trivy
trivy image cepatkilatteknologi/genieacs:1.2.13
```

---

## Production Checklist

### Before Deployment

- [ ] Generate unique JWT secret using `openssl rand -hex 32`
- [ ] Generate unique API key for NBI (if using nbi-auth)
- [ ] Generate unique MongoDB password using `openssl rand -base64 24`
- [ ] Update MongoDB connection URL with credentials
- [ ] Review and customize resource limits
- [ ] Configure persistent storage with backups
- [ ] Set up monitoring and alerting

### Network Security

- [ ] Enable NBI API authentication (use `nbi-auth` variant)
- [ ] Restrict NBI access to trusted networks/IPs
- [ ] Use TLS/HTTPS for all external traffic
- [ ] Consider NetworkPolicy for Kubernetes
- [ ] Don't expose MongoDB externally

### Operational Security

- [ ] Enable `GENIEACS_UI_AUTH=true`
- [ ] Use strong admin passwords
- [ ] Implement log monitoring
- [ ] Set up regular database backups
- [ ] Plan for secret rotation
- [ ] Keep images updated

### Monitoring

```bash
# Check for failed login attempts
kubectl logs -l app.kubernetes.io/name=genieacs -n genieacs | grep -i "auth"

# Monitor API access
kubectl logs -l app.kubernetes.io/name=genieacs -n genieacs -c nginx-nbi-auth
```

---

## Security Updates

### Updating Images

```bash
# Docker
docker compose pull
docker compose up -d

# Kubernetes
kubectl rollout restart deployment/genieacs -n genieacs

# Helm
helm repo update
helm upgrade genieacs genieacs/genieacs -n genieacs
```

### Subscribe to Security Notices

- Watch the [GitHub repository](https://github.com/Cepat-Kilat-Teknologi/genieacs-stack) for security updates
- Monitor [GenieACS releases](https://github.com/genieacs/genieacs/releases)
- Subscribe to Node.js security advisories

---

## Reporting Vulnerabilities

If you discover a security vulnerability, please report it responsibly:

1. **Do NOT** create a public GitHub issue
2. Email: info@ckt.co.id
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

We will respond within 48 hours and work with you to address the issue.

---

## Additional Resources

- [OWASP Container Security](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [GenieACS Documentation](https://docs.genieacs.com/)