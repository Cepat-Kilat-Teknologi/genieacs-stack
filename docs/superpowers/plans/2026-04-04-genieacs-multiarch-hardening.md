# GenieACS Multiarch Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all critical and high-severity issues (26 total) to make GenieACS stack production-ready for multiarch deployment on amd64/arm64 servers.

**Architecture:** Fix-and-harden approach — no structural rearchitecture. Prioritize Docker Compose path (primary), then Helm (secondary). All fixes applied consistently across deployment variants. Helm chart bumped to 0.3.0.

**Tech Stack:** Docker, Docker Compose, Helm 3, Kubernetes, GitHub Actions, Bash

---

## File Map

**Files to modify:**
- `Dockerfile` — upgrade GenieACS, remove non-reproducible npm commands, optimize multiarch
- `docker-compose.yml` — fix healthchecks, add resource limits/logging, standardize settings
- `examples/default/docker/docker-compose.yml` — standardize restart, image version
- `examples/nbi-auth/docker/docker-compose.yml` — standardize restart, image version
- `.env` — regenerate with secure defaults (will be gitignored)
- `.env.example` — fix MongoDB hostname, clean up unused vars
- `examples/default/docker/.env.example` — fix MongoDB hostname
- `examples/nbi-auth/docker/.env.example` — fix MongoDB hostname
- `.gitignore` — add patterns for example .env files
- `scripts/create-user.sh` — fix password exposure, safe .env loading
- `scripts/run_with_env.sh` — add service name validation
- `config/supervisord.conf` — add unix_http_server socket
- `.github/workflows/docker-build.yml` — fix version handling, fork PR login
- `.github/workflows/helm-release.yml` — add lint step, update Helm version
- `Makefile` — fix prune scope, add buildx-load, fix version, add lint targets
- `LICENSE` — fill in copyright boilerplate
- `examples/default/helm/genieacs/Chart.yaml` — bump to 0.3.0, add kubeVersion
- `examples/nbi-auth/helm/genieacs/Chart.yaml` — bump to 0.3.0, add kubeVersion
- `examples/default/helm/genieacs/values.yaml` — add security contexts, imagePullSecrets, required comments
- `examples/nbi-auth/helm/genieacs/values.yaml` — same
- `examples/default/helm/genieacs/templates/configmap.yaml` — move MongoDB URL to secret
- `examples/nbi-auth/helm/genieacs/templates/configmap.yaml` — same
- `examples/default/helm/genieacs/templates/genieacs-deployment.yaml` — replace init containers, add securityContext
- `examples/nbi-auth/helm/genieacs/templates/genieacs-deployment.yaml` — same + fix hardcoded port
- `examples/default/helm/genieacs/templates/mongodb-deployment.yaml` — fix probes, add securityContext
- `examples/nbi-auth/helm/genieacs/templates/mongodb-deployment.yaml` — same
- `examples/default/helm/genieacs/templates/secret.yaml` — add MongoDB URL, required validation
- `examples/nbi-auth/helm/genieacs/templates/secret.yaml` — same
- `examples/nbi-auth/helm/genieacs/templates/nginx-configmap.yaml` — fix hardcoded port

**Files to create:**
- `.github/workflows/security.yml` — Trivy vulnerability scanning
- `examples/default/helm/genieacs/templates/networkpolicy.yaml` — restrict MongoDB access
- `examples/nbi-auth/helm/genieacs/templates/networkpolicy.yaml` — same
- `examples/default/helm/genieacs/templates/pdb.yaml` — PodDisruptionBudget
- `examples/nbi-auth/helm/genieacs/templates/pdb.yaml` — same
- `examples/default/helm/genieacs/templates/serviceaccount.yaml` — ServiceAccount
- `examples/nbi-auth/helm/genieacs/templates/serviceaccount.yaml` — same

**Files to delete (from git tracking):**
- `examples/default/docker/.env` — git rm --cached
- `examples/nbi-auth/docker/.env` — git rm --cached

---

## Task 1: Fix Credential Exposure and .gitignore

**Files:**
- Modify: `.gitignore:60-65`
- Delete (from tracking): `examples/default/docker/.env`, `examples/nbi-auth/docker/.env`

**Issues addressed:** ISSUE-002 (CRITICAL), ISSUE-048 (LOW)

- [ ] **Step 1: Remove tracked .env files from git index**

```bash
git rm --cached examples/default/docker/.env examples/nbi-auth/docker/.env
```

Expected: files untracked but still on disk.

- [ ] **Step 2: Extend .gitignore to cover example .env files**

In `.gitignore`, replace the dotenv section (lines 60-65) with:

```gitignore
# dotenv environment variable files
.env
.env.development.local
.env.test.local
.env.production.local
.env.local
examples/**/.env
```

- [ ] **Step 3: Fix LICENSE copyright boilerplate**

In `LICENSE`, replace:

```
Copyright [yyyy] [name of copyright owner]
```

with:

```
Copyright 2024 Cepat Kilat Teknologi
```

- [ ] **Step 4: Commit**

```bash
git add .gitignore LICENSE
git commit -m "fix: remove tracked .env files, extend .gitignore, fix LICENSE copyright"
```

---

## Task 2: Upgrade GenieACS and Harden Dockerfile

**Files:**
- Modify: `Dockerfile` (full rewrite of build logic)

**Issues addressed:** ISSUE-001 (CRITICAL), ISSUE-008 (HIGH), ISSUE-029 (MEDIUM), ISSUE-050 (LOW), ISSUE-051 (LOW)

- [ ] **Step 1: Rewrite Dockerfile**

Replace entire `Dockerfile` content with:

```dockerfile
FROM node:24-bookworm-slim AS build

# Install GenieACS from npm
WORKDIR /opt/genieacs
ARG GENIEACS_VERSION=1.2.16
RUN npm install genieacs@${GENIEACS_VERSION}

##################################
# -------- Final image ----------#
##################################
FROM debian:bookworm-slim

# Install packages and apply security updates
RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends \
      supervisor ca-certificates logrotate curl \
 && rm -rf /var/lib/apt/lists/*

# Copy Node runtime and GenieACS artefacts from the build stage
COPY --from=build /usr/local /usr/local
COPY --from=build /opt/genieacs /opt/genieacs

# Supervisor configuration
COPY config/supervisord.conf /etc/supervisor/conf.d/genieacs.conf

# Helper script to run services
COPY scripts/run_with_env.sh /usr/local/bin/run_with_env.sh
RUN chmod +x /usr/local/bin/run_with_env.sh

# Logrotate configuration
COPY config/genieacs.logrotate /etc/logrotate.d/genieacs

# Create runtime user (supervisor runs as root but spawns services as genieacs)
RUN useradd --system --no-create-home --home /opt/genieacs genieacs \
 && mkdir -p /opt/genieacs/ext /var/log/genieacs \
 && chown -R genieacs:genieacs /opt/genieacs /var/log/genieacs

WORKDIR /opt/genieacs

EXPOSE 7547 7557 7567 3000
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/genieacs.conf"]
```

Key changes:
- `node:24-bookworm-slim` (was `node:24-bookworm`) — smaller build stage
- `GENIEACS_VERSION=1.2.16` (was `1.2.13`) — fixes critical RCE
- Removed `python3 make g++` — unnecessary for GenieACS 1.2.x (no native modules)
- Removed `--unsafe-perm` — deprecated in npm 7+
- Removed `npm audit fix --force || true` — non-reproducible anti-pattern
- Removed `npm update koa qs path-to-regexp glob tar --save || true` — non-reproducible
- Removed `wget` and `iputils-ping` from runtime — unused/debug tools

- [ ] **Step 2: Verify Dockerfile builds locally**

```bash
docker build -t genieacs-test:local .
```

Expected: successful build with no errors.

- [ ] **Step 3: Verify GenieACS version inside built image**

```bash
docker run --rm genieacs-test:local node -e "console.log(require('/opt/genieacs/node_modules/genieacs/package.json').version)"
```

Expected: `1.2.16`

- [ ] **Step 4: Commit**

```bash
git add Dockerfile
git commit -m "fix: upgrade GenieACS to 1.2.16 (RCE fix), harden Dockerfile for multiarch"
```

---

## Task 3: Fix .env.example Files — MongoDB Hostname and Cleanup

**Files:**
- Modify: `.env.example:32`
- Modify: `examples/default/docker/.env.example:32`
- Modify: `examples/nbi-auth/docker/.env.example:34`
- Modify: `.env`

**Issues addressed:** ISSUE-009 (HIGH), ISSUE-044 (MEDIUM)

- [ ] **Step 1: Fix root .env.example — change `mongodb` to `mongo`**

In `.env.example`, replace line 32:

```
GENIEACS_MONGODB_CONNECTION_URL=mongodb://admin:changeme-generate-secure-password@mongodb:27017/genieacs?authSource=admin
```

with:

```
GENIEACS_MONGODB_CONNECTION_URL=mongodb://admin:changeme-generate-secure-password@mongo:27017/genieacs?authSource=admin
```

- [ ] **Step 2: Fix examples/default/docker/.env.example — change `mongodb` to `mongo`**

In `examples/default/docker/.env.example`, replace line 32:

```
GENIEACS_MONGODB_CONNECTION_URL=mongodb://admin:YOUR_PASSWORD_HERE@mongodb:27017/genieacs?authSource=admin
```

with:

```
GENIEACS_MONGODB_CONNECTION_URL=mongodb://admin:YOUR_PASSWORD_HERE@mongo:27017/genieacs?authSource=admin
```

- [ ] **Step 3: Fix examples/nbi-auth/docker/.env.example — change `mongodb` to `mongo`**

In `examples/nbi-auth/docker/.env.example`, replace line 34:

```
GENIEACS_MONGODB_CONNECTION_URL=mongodb://admin:YOUR_PASSWORD_HERE@mongodb:27017/genieacs?authSource=admin
```

with:

```
GENIEACS_MONGODB_CONNECTION_URL=mongodb://admin:YOUR_PASSWORD_HERE@mongo:27017/genieacs?authSource=admin
```

- [ ] **Step 4: Fix root .env — change `mongodb` to `mongo`**

In `.env`, replace line 7:

```
GENIEACS_MONGODB_CONNECTION_URL=mongodb://admin:password123@mongodb:27017/genieacs?authSource=admin
```

with:

```
GENIEACS_MONGODB_CONNECTION_URL=mongodb://admin:password123@mongo:27017/genieacs?authSource=admin
```

- [ ] **Step 5: Commit**

```bash
git add .env.example examples/default/docker/.env.example examples/nbi-auth/docker/.env.example
git commit -m "fix: correct MongoDB hostname from 'mongodb' to 'mongo' in all env files"
```

Note: `.env` is gitignored so it won't be committed.

---

## Task 4: Standardize Docker Compose Files

**Files:**
- Modify: `docker-compose.yml`
- Modify: `examples/default/docker/docker-compose.yml`
- Modify: `examples/nbi-auth/docker/docker-compose.yml`

**Issues addressed:** ISSUE-019 (HIGH), ISSUE-024 (HIGH), ISSUE-030 (MEDIUM), ISSUE-031 (MEDIUM), ISSUE-032 (MEDIUM)

- [ ] **Step 1: Update root docker-compose.yml**

Replace the full `docker-compose.yml` with:

```yaml
# Requires Docker Compose v2 (docker compose)
services:
  ### Main GenieACS DB: MongoDB ###
  mongo:
    image: mongo:8.0
    restart: unless-stopped
    container_name: mongo-genieacs
    environment:
      MONGO_DATA_DIR: /data/db
      MONGO_LOG_DIR: /var/log/mongodb
      # Authentication - REQUIRED for security
      MONGO_INITDB_ROOT_USERNAME: ${MONGO_INITDB_ROOT_USERNAME:-admin}
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_INITDB_ROOT_PASSWORD:?MongoDB password is required}
    volumes:
      - mongo_data:/data/db
      - mongo_configdb:/data/configdb
    networks:
      - genieacs_network
    healthcheck:
      test: ["CMD", "mongosh", "--quiet", "--eval", "db.adminCommand('ping')", "mongodb://${MONGO_INITDB_ROOT_USERNAME:-admin}:${MONGO_INITDB_ROOT_PASSWORD}@localhost:27017/admin?authSource=admin"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
    logging:
      driver: "json-file"
      options:
        max-size: "50m"
        max-file: "5"

  ### GenieACS Application ###
  genieacs:
    depends_on:
      mongo:
        condition: service_healthy
    image: cepatkilatteknologi/genieacs:1.2.16
    restart: unless-stopped
    container_name: genieacs
    environment:
      # Security settings
      GENIEACS_UI_JWT_SECRET: ${GENIEACS_UI_JWT_SECRET:?JWT secret is required}
      GENIEACS_UI_AUTH: ${GENIEACS_UI_AUTH:-true}
      # Log files
      GENIEACS_CWMP_ACCESS_LOG_FILE: /var/log/genieacs/cwmp-access.log
      GENIEACS_NBI_ACCESS_LOG_FILE: /var/log/genieacs/nbi-access.log
      GENIEACS_FS_ACCESS_LOG_FILE: /var/log/genieacs/fs-access.log
      GENIEACS_UI_ACCESS_LOG_FILE: /var/log/genieacs/ui-access.log
      GENIEACS_DEBUG_FILE: /var/log/genieacs/debug.yaml
      # Paths
      GENIEACS_EXT_DIR: /opt/genieacs/ext
      # MongoDB with authentication
      GENIEACS_MONGODB_CONNECTION_URL: ${GENIEACS_MONGODB_CONNECTION_URL:-mongodb://${MONGO_INITDB_ROOT_USERNAME:-admin}:${MONGO_INITDB_ROOT_PASSWORD}@mongo:27017/genieacs?authSource=admin}
      NODE_ENV: production
    ports:
      # CWMP (TR-069) - CPE devices connect here
      - "${GENIEACS_CWMP_PORT:-7547}:7547"
      # NBI API
      - "${GENIEACS_NBI_PORT:-7557}:7557"
      # File Server
      - "${GENIEACS_FS_PORT:-7567}:7567"
      # Web UI
      - "${GENIEACS_UI_PORT:-3000}:3000"
    volumes:
      - genieacs_data:/opt/genieacs
      - genieacs_logs:/var/log/genieacs
      - ./ext:/opt/genieacs/ext:ro
    networks:
      - genieacs_network
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:3000/", "-o", "/dev/null", "&&", "curl", "-sf", "http://localhost:7557/", "-o", "/dev/null"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 90s
    security_opt:
      - no-new-privileges:true
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 1G
        reservations:
          cpus: '0.25'
          memory: 256M
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "10"

volumes:
  mongo_data:
    name: genieacs-mongo-data
  mongo_configdb:
    name: genieacs-mongo-configdb
  genieacs_data:
    name: genieacs-app-data
  genieacs_logs:
    name: genieacs-logs

networks:
  genieacs_network:
    name: genieacs-network
    driver: bridge
```

Key changes from original:
- MongoDB healthcheck uses connection string (no password in process list)
- `start_period: 30s` for MongoDB (was 20s)
- `start_period: 90s` for GenieACS (was 60s)
- Added resource limits and logging (was missing)
- Removed `read_only: false` (was misleading)
- Image bumped to `1.2.16`
- GenieACS healthcheck tests both UI and NBI

- [ ] **Step 2: Update examples/default/docker/docker-compose.yml**

Change `restart: always` to `restart: unless-stopped` on lines 16 and 52.

Change image from `cepatkilatteknologi/genieacs:1.2.13` to `cepatkilatteknologi/genieacs:1.2.16` on line 50.

Change MongoDB healthcheck (line 29) from:
```yaml
      test: ["CMD", "mongosh", "-u", "${MONGO_INITDB_ROOT_USERNAME:-admin}", "-p", "${MONGO_INITDB_ROOT_PASSWORD}", "--authenticationDatabase", "admin", "--eval", "db.adminCommand('ping')"]
```
to:
```yaml
      test: ["CMD", "mongosh", "--quiet", "--eval", "db.adminCommand('ping')", "mongodb://${MONGO_INITDB_ROOT_USERNAME:-admin}:${MONGO_INITDB_ROOT_PASSWORD}@localhost:27017/admin?authSource=admin"]
```

Change GenieACS healthcheck (line 86) from:
```yaml
      test: ["CMD", "curl", "-f", "http://localhost:3000/"]
```
to:
```yaml
      test: ["CMD-SHELL", "curl -sf http://localhost:3000/ && curl -sf http://localhost:7557/"]
```

- [ ] **Step 3: Update examples/nbi-auth/docker/docker-compose.yml**

Same changes as Step 2:
- `restart: always` → `restart: unless-stopped` on lines 14, 50, 109
- Image `1.2.13` → `1.2.16` on line 48
- MongoDB healthcheck connection string format on line 27
- GenieACS healthcheck multi-service check on line 84

- [ ] **Step 4: Commit**

```bash
git add docker-compose.yml examples/default/docker/docker-compose.yml examples/nbi-auth/docker/docker-compose.yml
git commit -m "fix: standardize compose files — secure healthchecks, resource limits, consistent settings"
```

---

## Task 5: Fix Scripts Security

**Files:**
- Modify: `scripts/create-user.sh:17-18,57-63,65-71`
- Modify: `scripts/run_with_env.sh:22-23`

**Issues addressed:** ISSUE-020 (HIGH), ISSUE-041 (MEDIUM)

- [ ] **Step 1: Fix create-user.sh — safe .env loading and stdin password**

Replace line 17-18:
```bash
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs 2>/dev/null) || true
fi
```

with:
```bash
if [ -f .env ]; then
    set -a
    . ./.env
    set +a
fi
```

Replace lines 57-63 (docker exec hash generation):
```bash
    HASH_OUTPUT=$(docker exec genieacs node -e "
const crypto = require('crypto');
const password = process.argv[1];
const salt = crypto.randomBytes(64).toString('hex');
const hash = crypto.pbkdf2Sync(password, salt, 10000, 128, 'sha512').toString('hex');
console.log(JSON.stringify({salt: salt, hash: hash}));
" "$PASSWORD")
```

with:
```bash
    HASH_OUTPUT=$(docker exec -e GENIE_PASS="$PASSWORD" genieacs node -e "
const crypto = require('crypto');
const password = process.env.GENIE_PASS;
const salt = crypto.randomBytes(64).toString('hex');
const hash = crypto.pbkdf2Sync(password, salt, 10000, 128, 'sha512').toString('hex');
console.log(JSON.stringify({salt: salt, hash: hash}));
")
```

Replace lines 65-71 (local node hash generation):
```bash
    HASH_OUTPUT=$(node -e "
const crypto = require('crypto');
const password = process.argv[1];
const salt = crypto.randomBytes(64).toString('hex');
const hash = crypto.pbkdf2Sync(password, salt, 10000, 128, 'sha512').toString('hex');
console.log(JSON.stringify({salt: salt, hash: hash}));
" "$PASSWORD")
```

with:
```bash
    HASH_OUTPUT=$(GENIE_PASS="$PASSWORD" node -e "
const crypto = require('crypto');
const password = process.env.GENIE_PASS;
const salt = crypto.randomBytes(64).toString('hex');
const hash = crypto.pbkdf2Sync(password, salt, 10000, 128, 'sha512').toString('hex');
console.log(JSON.stringify({salt: salt, hash: hash}));
")
```

- [ ] **Step 2: Fix run_with_env.sh — add service name whitelist**

Replace lines 22-23:
```bash
# Execute the service from node_modules/.bin
exec /opt/genieacs/node_modules/.bin/$SERVICE
```

with:
```bash
# Validate service name
case "$SERVICE" in
    genieacs-cwmp|genieacs-nbi|genieacs-fs|genieacs-ui) ;;
    *) echo "Error: Invalid service '$SERVICE'"; exit 1 ;;
esac

# Execute the service from node_modules/.bin
exec /opt/genieacs/node_modules/.bin/$SERVICE
```

- [ ] **Step 3: Commit**

```bash
git add scripts/create-user.sh scripts/run_with_env.sh
git commit -m "fix: secure password handling in create-user.sh, add service validation in run_with_env.sh"
```

---

## Task 6: Fix CI/CD — Docker Build Workflow

**Files:**
- Modify: `.github/workflows/docker-build.yml`

**Issues addressed:** ISSUE-006 (CRITICAL), ISSUE-012 (HIGH), ISSUE-014 (HIGH)

- [ ] **Step 1: Fix docker-build.yml**

Replace line 12:
```yaml
  IMAGE_VERSION: '1.2.13'
```

with:
```yaml
  IMAGE_VERSION: '1.2.16'
```

Add condition to Docker Hub login (lines 45-50), change to:
```yaml
      - name: Log in to Docker Hub
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          registry: ${{ env.DOCKERHUB_REGISTRY }}
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
```

Add condition to GHCR login (lines 53-58), change to:
```yaml
      - name: Log in to GitHub Container Registry
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          registry: ${{ env.GHCR_REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/docker-build.yml
git commit -m "fix: upgrade image version to 1.2.16, skip registry login on PRs"
```

---

## Task 7: Add Security Scanning Workflow

**Files:**
- Create: `.github/workflows/security.yml`

**Issues addressed:** ISSUE-006 (CRITICAL)

- [ ] **Step 1: Create security.yml**

```yaml
name: Security Scan

on:
  push:
    branches: [main]
    paths:
      - 'Dockerfile'
      - 'config/**'
      - 'scripts/**'
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 6 * * 1'  # Weekly Monday 6am UTC
  workflow_dispatch:

jobs:
  trivy-scan:
    name: Trivy Vulnerability Scan
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build image for scanning
        run: docker build -t genieacs-scan:latest .

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'genieacs-scan:latest'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'

      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Run Trivy config scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'config'
          scan-ref: '.'
          format: 'table'
          severity: 'CRITICAL,HIGH'
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/security.yml
git commit -m "feat: add Trivy security scanning workflow"
```

---

## Task 8: Fix Helm Release Workflow

**Files:**
- Modify: `.github/workflows/helm-release.yml`

**Issues addressed:** ISSUE-007 (CRITICAL)

- [ ] **Step 1: Add lint step and update Helm version**

In `helm-release.yml`, change line 31:
```yaml
          version: v3.14.0
```
to:
```yaml
          version: v3.16.3
```

Insert a new step after "Install Helm" (after line 31) and before "Package Helm Charts":

```yaml
      - name: Lint Helm Charts
        run: |
          echo "Linting genieacs chart..."
          helm lint examples/default/helm/genieacs --strict

          echo "Linting genieacs-nbi-auth chart..."
          helm lint examples/nbi-auth/helm/genieacs --strict

          echo "Template rendering test - default..."
          helm template test examples/default/helm/genieacs > /dev/null

          echo "Template rendering test - nbi-auth..."
          helm template test examples/nbi-auth/helm/genieacs > /dev/null

          echo "All charts passed validation!"
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/helm-release.yml
git commit -m "fix: add Helm lint/template validation before publishing, update Helm to v3.16.3"
```

---

## Task 9: Helm — Move MongoDB Password Out of ConfigMap

**Files:**
- Modify: `examples/default/helm/genieacs/templates/configmap.yaml`
- Modify: `examples/default/helm/genieacs/templates/secret.yaml`
- Modify: `examples/nbi-auth/helm/genieacs/templates/configmap.yaml`
- Modify: `examples/nbi-auth/helm/genieacs/templates/secret.yaml`

**Issues addressed:** ISSUE-003 (CRITICAL), ISSUE-004 (CRITICAL), ISSUE-039 (MEDIUM)

- [ ] **Step 1: Rewrite default configmap.yaml — remove password from ConfigMap**

Replace `examples/default/helm/genieacs/templates/configmap.yaml` entirely:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "genieacs.fullname" . }}-config
  labels:
    {{- include "genieacs.labels" . | nindent 4 }}
    app.kubernetes.io/component: config
data:
  GENIEACS_UI_AUTH: {{ .Values.config.uiAuth | quote }}
  GENIEACS_EXT_DIR: {{ .Values.config.extDir | quote }}
  NODE_ENV: {{ .Values.config.nodeEnv | quote }}
```

- [ ] **Step 2: Rewrite default secret.yaml — add MongoDB URL and required validation**

Replace `examples/default/helm/genieacs/templates/secret.yaml` entirely:

```yaml
{{- if not .Values.secret.existingSecret }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "genieacs.fullname" . }}-secret
  labels:
    {{- include "genieacs.labels" . | nindent 4 }}
    app.kubernetes.io/component: secret
type: Opaque
stringData:
  GENIEACS_UI_JWT_SECRET: {{ required "secret.jwtSecret must be set (generate with: openssl rand -hex 32)" .Values.secret.jwtSecret | quote }}
  {{- if .Values.mongodb.enabled }}
  {{- if .Values.mongodb.auth.enabled }}
  GENIEACS_MONGODB_CONNECTION_URL: {{ printf "mongodb://%s:%s@%s:%d/genieacs?authSource=admin" (required "mongodb.auth.rootUsername is required" .Values.mongodb.auth.rootUsername) (required "mongodb.auth.rootPassword is required" .Values.mongodb.auth.rootPassword) (include "genieacs.mongodb.name" .) (int .Values.mongodb.service.port) | quote }}
  {{- else }}
  GENIEACS_MONGODB_CONNECTION_URL: {{ printf "mongodb://%s:%d/genieacs" (include "genieacs.mongodb.name" .) (int .Values.mongodb.service.port) | quote }}
  {{- end }}
  {{- else }}
  GENIEACS_MONGODB_CONNECTION_URL: {{ .Values.config.mongodbConnectionUrl | quote }}
  {{- end }}
{{- end }}
```

- [ ] **Step 3: Apply same changes to nbi-auth configmap.yaml**

Replace `examples/nbi-auth/helm/genieacs/templates/configmap.yaml` with the same content as Step 1 (identical — the NBI ConfigMap should only have non-secret config).

- [ ] **Step 4: Apply same changes to nbi-auth secret.yaml**

Replace `examples/nbi-auth/helm/genieacs/templates/secret.yaml` with the same content as Step 2 (identical structure).

- [ ] **Step 5: Fix nbi-auth nginx-configmap.yaml — template the port**

In `examples/nbi-auth/helm/genieacs/templates/nginx-configmap.yaml`, replace line 45:
```
                proxy_pass http://127.0.0.1:7557;
```
with:
```
                proxy_pass http://127.0.0.1:{{ .Values.genieacs.service.ports.nbi }};
```

- [ ] **Step 6: Commit**

```bash
git add examples/default/helm/genieacs/templates/configmap.yaml \
        examples/default/helm/genieacs/templates/secret.yaml \
        examples/nbi-auth/helm/genieacs/templates/configmap.yaml \
        examples/nbi-auth/helm/genieacs/templates/secret.yaml \
        examples/nbi-auth/helm/genieacs/templates/nginx-configmap.yaml
git commit -m "fix: move MongoDB credentials from ConfigMap to Secret, add required validation, fix hardcoded port"
```

---

## Task 10: Helm — Fix Init Containers and Security Contexts

**Files:**
- Modify: `examples/default/helm/genieacs/templates/genieacs-deployment.yaml`
- Modify: `examples/nbi-auth/helm/genieacs/templates/genieacs-deployment.yaml`
- Modify: `examples/default/helm/genieacs/values.yaml`
- Modify: `examples/nbi-auth/helm/genieacs/values.yaml`

**Issues addressed:** ISSUE-005 (CRITICAL), ISSUE-018 (HIGH), ISSUE-022 (HIGH), ISSUE-026 (HIGH)

- [ ] **Step 1: Update default values.yaml — add pod security context and serviceAccount**

In `examples/default/helm/genieacs/values.yaml`, replace lines 70-72:
```yaml
  # Security context
  securityContext:
    allowPrivilegeEscalation: false
```

with:
```yaml
  # Pod-level security context
  podSecurityContext:
    fsGroup: 1000
    runAsUser: 1000
    runAsGroup: 1000
    runAsNonRoot: true

  # Container-level security context
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: false
    capabilities:
      drop:
        - ALL
```

Replace lines 166-169:
```yaml
serviceAccount:
  create: false
  name: ""
  annotations: {}
```

with:
```yaml
serviceAccount:
  create: true
  name: ""
  annotations: {}

# Image pull secrets for private registries
imagePullSecrets: []
```

- [ ] **Step 2: Update nbi-auth values.yaml — same security context changes**

Apply the same changes to `examples/nbi-auth/helm/genieacs/values.yaml`:
- Same `podSecurityContext` and `securityContext` changes
- Same `serviceAccount.create: true` change
- Same `imagePullSecrets: []` addition

- [ ] **Step 3: Rewrite default genieacs-deployment.yaml**

Replace `examples/default/helm/genieacs/templates/genieacs-deployment.yaml` entirely:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "genieacs.fullname" . }}
  labels:
    {{- include "genieacs.labels" . | nindent 4 }}
    app.kubernetes.io/component: app
spec:
  replicas: {{ .Values.genieacs.replicaCount }}
  strategy:
    type: Recreate
  selector:
    matchLabels:
      {{- include "genieacs.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "genieacs.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: app
    spec:
      serviceAccountName: {{ include "genieacs.serviceAccountName" . }}
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      securityContext:
        {{- toYaml .Values.genieacs.podSecurityContext | nindent 8 }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      initContainers:
        - name: wait-for-mongodb
          image: "{{ .Values.genieacs.initContainers.busybox.image }}:{{ .Values.genieacs.initContainers.busybox.tag }}"
          command:
            - sh
            - -c
            - |
              TIMEOUT=300
              ELAPSED=0
              until nc -z {{ include "genieacs.mongodb.name" . }} {{ .Values.mongodb.service.port }}; do
                echo "Waiting for MongoDB... ($ELAPSED/$TIMEOUT)"
                sleep 2
                ELAPSED=$((ELAPSED + 2))
                if [ $ELAPSED -ge $TIMEOUT ]; then
                  echo "Timeout waiting for MongoDB"
                  exit 1
                fi
              done
              echo "MongoDB is ready!"
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
      containers:
        - name: genieacs
          image: "{{ .Values.genieacs.image.repository }}:{{ .Values.genieacs.image.tag }}"
          imagePullPolicy: {{ .Values.genieacs.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.genieacs.service.ports.cwmp }}
              name: cwmp
            - containerPort: {{ .Values.genieacs.service.ports.nbi }}
              name: nbi
            - containerPort: {{ .Values.genieacs.service.ports.fs }}
              name: fs
            - containerPort: {{ .Values.genieacs.service.ports.ui }}
              name: ui
          envFrom:
            - configMapRef:
                name: {{ include "genieacs.fullname" . }}-config
            - secretRef:
                name: {{ .Values.secret.existingSecret | default (printf "%s-secret" (include "genieacs.fullname" .)) }}
          volumeMounts:
            - name: genieacs-logs
              mountPath: /var/log/genieacs
            - name: genieacs-ext
              mountPath: /opt/genieacs/ext
          resources:
            {{- toYaml .Values.genieacs.resources | nindent 12 }}
          startupProbe:
            httpGet:
              path: /
              port: {{ .Values.genieacs.service.ports.ui }}
            failureThreshold: 30
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: {{ .Values.genieacs.service.ports.ui }}
            periodSeconds: {{ .Values.genieacs.livenessProbe.periodSeconds }}
            timeoutSeconds: {{ .Values.genieacs.livenessProbe.timeoutSeconds }}
            failureThreshold: {{ .Values.genieacs.livenessProbe.failureThreshold }}
          readinessProbe:
            httpGet:
              path: /
              port: {{ .Values.genieacs.service.ports.ui }}
            periodSeconds: {{ .Values.genieacs.readinessProbe.periodSeconds }}
            timeoutSeconds: {{ .Values.genieacs.readinessProbe.timeoutSeconds }}
            failureThreshold: {{ .Values.genieacs.readinessProbe.failureThreshold }}
          securityContext:
            {{- toYaml .Values.genieacs.securityContext | nindent 12 }}
      volumes:
        - name: genieacs-logs
          {{- if .Values.genieacs.persistence.logs.enabled }}
          persistentVolumeClaim:
            claimName: {{ include "genieacs.fullname" . }}-logs
          {{- else }}
          emptyDir: {}
          {{- end }}
        - name: genieacs-ext
          {{- if .Values.genieacs.persistence.ext.enabled }}
          persistentVolumeClaim:
            claimName: {{ include "genieacs.fullname" . }}-ext
          {{- else }}
          emptyDir: {}
          {{- end }}
```

Key changes:
- Removed `fix-permissions` init container — replaced by `podSecurityContext.fsGroup: 1000`
- Added timeout (300s) to `wait-for-mongodb` init container
- Added `securityContext` to init container
- Added `serviceAccountName` and `imagePullSecrets`
- Added `startupProbe` — replaces large `initialDelaySeconds` on liveness
- Removed `initialDelaySeconds` from liveness/readiness (startupProbe handles slow startup)
- All ports templated from values

- [ ] **Step 4: Rewrite nbi-auth genieacs-deployment.yaml**

Replace `examples/nbi-auth/helm/genieacs/templates/genieacs-deployment.yaml` with the same structure as Step 3, but with the nginx sidecar added back:

After the `containers:` line and before `- name: genieacs`, add:

```yaml
        {{- if .Values.nbiAuth.enabled }}
        # Nginx sidecar for NBI API Key Authentication
        - name: nginx-nbi-auth
          image: "{{ .Values.nbiAuth.image.repository }}:{{ .Values.nbiAuth.image.tag }}"
          imagePullPolicy: {{ .Values.nbiAuth.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.nbiAuth.internalPort }}
              name: nbi-auth
          volumeMounts:
            - name: nginx-config
              mountPath: /etc/nginx/nginx.conf
              subPath: nginx.conf
          resources:
            {{- toYaml .Values.nbiAuth.resources | nindent 12 }}
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false
            capabilities:
              drop:
                - ALL
        {{- end }}
```

And the NBI container port on the genieacs container must use `{{ .Values.genieacs.service.ports.nbi }}` instead of hardcoded `7557`.

At the end of volumes section, add:
```yaml
        {{- if .Values.nbiAuth.enabled }}
        - name: nginx-config
          configMap:
            name: {{ include "genieacs.fullname" . }}-nginx-config
        {{- end }}
```

- [ ] **Step 5: Commit**

```bash
git add examples/default/helm/genieacs/templates/genieacs-deployment.yaml \
        examples/nbi-auth/helm/genieacs/templates/genieacs-deployment.yaml \
        examples/default/helm/genieacs/values.yaml \
        examples/nbi-auth/helm/genieacs/values.yaml
git commit -m "fix: replace root init container with fsGroup, add security contexts, fix ports, add startupProbe"
```

---

## Task 11: Helm — Fix MongoDB Deployment Probes

**Files:**
- Modify: `examples/default/helm/genieacs/templates/mongodb-deployment.yaml:56-75`
- Modify: `examples/nbi-auth/helm/genieacs/templates/mongodb-deployment.yaml`

**Issues addressed:** ISSUE-010 (HIGH), ISSUE-018 (HIGH)

- [ ] **Step 1: Fix default mongodb-deployment.yaml probes**

In `examples/default/helm/genieacs/templates/mongodb-deployment.yaml`, replace lines 44-48 (env block):
```yaml
          env:
            - name: MONGO_DATA_DIR
              value: /data/db
            - name: MONGO_LOG_DIR
              value: /var/log/mongodb
```

with (remove non-functional env vars):
```yaml
```
(delete those lines entirely — `MONGO_DATA_DIR` and `MONGO_LOG_DIR` are not real MongoDB variables)

Replace lines 56-75 (probes):
```yaml
          livenessProbe:
            exec:
              command:
                - mongosh
                - --eval
                - "db.adminCommand('ping')"
```

with:
```yaml
          livenessProbe:
            exec:
              command:
                - mongosh
                - --quiet
                - --eval
                - "db.adminCommand('ping')"
                - "mongodb://$(MONGO_INITDB_ROOT_USERNAME):$(MONGO_INITDB_ROOT_PASSWORD)@localhost:27017/admin?authSource=admin"
```

Same change for `readinessProbe`.

Add pod-level security context after `spec:` > `template:` > `spec:`:
```yaml
      securityContext:
        fsGroup: 999
```

Add container security context replacing line 76-77:
```yaml
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
```

- [ ] **Step 2: Apply same changes to nbi-auth mongodb-deployment.yaml**

Same probe and security context fixes.

- [ ] **Step 3: Commit**

```bash
git add examples/default/helm/genieacs/templates/mongodb-deployment.yaml \
        examples/nbi-auth/helm/genieacs/templates/mongodb-deployment.yaml
git commit -m "fix: MongoDB probes with auth credentials, add security contexts, remove non-functional env vars"
```

---

## Task 12: Helm — Add NetworkPolicy, PDB, ServiceAccount

**Files:**
- Create: `examples/default/helm/genieacs/templates/networkpolicy.yaml`
- Create: `examples/default/helm/genieacs/templates/pdb.yaml`
- Create: `examples/default/helm/genieacs/templates/serviceaccount.yaml`
- Create: same 3 files in `examples/nbi-auth/helm/genieacs/templates/`

**Issues addressed:** ISSUE-015 (HIGH), ISSUE-016 (HIGH), ISSUE-026 (HIGH)

- [ ] **Step 1: Create networkpolicy.yaml (default)**

Write to `examples/default/helm/genieacs/templates/networkpolicy.yaml`:

```yaml
{{- if .Values.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "genieacs.mongodb.name" . }}
  labels:
    {{- include "genieacs.mongodb.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "genieacs.mongodb.selectorLabels" . | nindent 6 }}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              {{- include "genieacs.selectorLabels" . | nindent 14 }}
      ports:
        - port: {{ .Values.mongodb.service.port }}
          protocol: TCP
{{- end }}
```

- [ ] **Step 2: Create pdb.yaml (default)**

Write to `examples/default/helm/genieacs/templates/pdb.yaml`:

```yaml
{{- if .Values.podDisruptionBudget.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "genieacs.fullname" . }}
  labels:
    {{- include "genieacs.labels" . | nindent 4 }}
spec:
  {{- if .Values.podDisruptionBudget.minAvailable }}
  minAvailable: {{ .Values.podDisruptionBudget.minAvailable }}
  {{- end }}
  {{- if .Values.podDisruptionBudget.maxUnavailable }}
  maxUnavailable: {{ .Values.podDisruptionBudget.maxUnavailable }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "genieacs.selectorLabels" . | nindent 6 }}
{{- end }}
```

- [ ] **Step 3: Create serviceaccount.yaml (default)**

Write to `examples/default/helm/genieacs/templates/serviceaccount.yaml`:

```yaml
{{- if .Values.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "genieacs.serviceAccountName" . }}
  labels:
    {{- include "genieacs.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

- [ ] **Step 4: Copy all 3 files to nbi-auth variant**

Copy the same 3 files to `examples/nbi-auth/helm/genieacs/templates/`.

- [ ] **Step 5: Add values for new resources to both values.yaml files**

Append to both `examples/default/helm/genieacs/values.yaml` and `examples/nbi-auth/helm/genieacs/values.yaml`:

```yaml

# Network Policy - restrict MongoDB access
networkPolicy:
  enabled: false

# Pod Disruption Budget
podDisruptionBudget:
  enabled: false
  # minAvailable: 1
  # maxUnavailable: 1
```

- [ ] **Step 6: Commit**

```bash
git add examples/default/helm/genieacs/templates/networkpolicy.yaml \
        examples/default/helm/genieacs/templates/pdb.yaml \
        examples/default/helm/genieacs/templates/serviceaccount.yaml \
        examples/nbi-auth/helm/genieacs/templates/networkpolicy.yaml \
        examples/nbi-auth/helm/genieacs/templates/pdb.yaml \
        examples/nbi-auth/helm/genieacs/templates/serviceaccount.yaml \
        examples/default/helm/genieacs/values.yaml \
        examples/nbi-auth/helm/genieacs/values.yaml
git commit -m "feat: add NetworkPolicy, PodDisruptionBudget, and ServiceAccount templates"
```

---

## Task 13: Helm — Bump Chart Version and Update Metadata

**Files:**
- Modify: `examples/default/helm/genieacs/Chart.yaml`
- Modify: `examples/nbi-auth/helm/genieacs/Chart.yaml`

**Issues addressed:** Chart version bump to 0.3.0

- [ ] **Step 1: Update default Chart.yaml**

In `examples/default/helm/genieacs/Chart.yaml`, change:
```yaml
version: 0.2.0
appVersion: "1.2.13"
```
to:
```yaml
version: 0.3.0
appVersion: "1.2.16"
kubeVersion: ">=1.25.0-0"
```

- [ ] **Step 2: Update nbi-auth Chart.yaml**

In `examples/nbi-auth/helm/genieacs/Chart.yaml`, change:
```yaml
version: 0.2.0
appVersion: "1.2.13"
```
to:
```yaml
version: 0.3.0
appVersion: "1.2.16"
kubeVersion: ">=1.25.0-0"
```

- [ ] **Step 3: Commit**

```bash
git add examples/default/helm/genieacs/Chart.yaml examples/nbi-auth/helm/genieacs/Chart.yaml
git commit -m "chore: bump Helm chart version to 0.3.0, appVersion to 1.2.16, add kubeVersion constraint"
```

---

## Task 14: Fix Makefile

**Files:**
- Modify: `Makefile`

**Issues addressed:** ISSUE-013 (HIGH), ISSUE-023 (HIGH), ISSUE-038 (MEDIUM)

- [ ] **Step 1: Update Makefile version and add targets**

Change line 7:
```makefile
VERSION = v1.2.13
```
to:
```makefile
VERSION = v1.2.16
```

Replace lines 203-206 (`prune` target):
```makefile
prune:
	docker system prune -f
	docker volume prune -f
```
with:
```makefile
prune:
	$(COMPOSE) down --rmi local --volumes --remove-orphans
	@echo "Project resources pruned"
```

Add new target after `buildx` (after line 68):
```makefile
# Build for local architecture and load into Docker
buildx-load:
	docker buildx build --platform linux/$$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
		--load -t $(IMAGE_NAME):$(TAG) -t $(IMAGE_NAME):$(LATEST) .
```

Add lint targets before `# Default target` (or at end of file):
```makefile
# Lint Dockerfile
lint-docker:
	@docker run --rm -i hadolint/hadolint < Dockerfile

# Lint Helm charts
lint-helm:
	@helm lint examples/default/helm/genieacs --strict
	@helm lint examples/nbi-auth/helm/genieacs --strict
	@echo "All Helm charts passed linting"

# Render Helm templates
helm-template:
	@helm template test examples/default/helm/genieacs
	@helm template test examples/nbi-auth/helm/genieacs
```

Update the help target to include new commands.

- [ ] **Step 2: Commit**

```bash
git add Makefile
git commit -m "fix: update version to v1.2.16, scope prune to project, add buildx-load and lint targets"
```

---

## Task 15: Update .dockerignore

**Files:**
- Modify: `.dockerignore`

- [ ] **Step 1: Add missing exclusions**

Append to `.dockerignore`:

```
# Exclude non-build directories from context
examples/
docs/
backups/
.github/
ISSUE.md
TODO.md
INSTALLATION.md
SECURITY.md
```

- [ ] **Step 2: Commit**

```bash
git add .dockerignore
git commit -m "chore: exclude examples/, docs/, and non-build files from Docker context"
```

---

## Task 16: Validation — Test Everything

- [ ] **Step 1: Verify Docker build**

```bash
make build
```

Expected: successful build.

- [ ] **Step 2: Verify Helm lint**

```bash
make lint-helm
```

Expected: both charts pass linting with no errors.

- [ ] **Step 3: Verify Helm template rendering**

```bash
make helm-template > /dev/null
```

Expected: no template errors.

- [ ] **Step 4: Verify Docker Compose config**

```bash
docker compose -f docker-compose.yml config > /dev/null 2>&1 && echo "OK" || echo "FAIL"
docker compose -f examples/default/docker/docker-compose.yml config > /dev/null 2>&1 && echo "OK" || echo "FAIL"
docker compose -f examples/nbi-auth/docker/docker-compose.yml config > /dev/null 2>&1 && echo "OK" || echo "FAIL"
```

Note: may show warnings about unset env vars — that's expected without a real `.env`.

- [ ] **Step 5: Verify no secrets in git-tracked files**

```bash
git diff --cached --name-only | grep -E '\.env$' && echo "WARNING: .env files staged!" || echo "OK: no .env files staged"
```

---

## Summary of Issues Addressed

| Issue | Severity | Status |
|-------|----------|--------|
| ISSUE-001: RCE vulnerability (1.2.13) | CRITICAL | Task 2 |
| ISSUE-002: Credentials in git | CRITICAL | Task 1 |
| ISSUE-003: MongoDB password in ConfigMap | CRITICAL | Task 9 |
| ISSUE-004: NBI API key in ConfigMap | CRITICAL | Task 9 |
| ISSUE-005: Root init container | CRITICAL | Task 10 |
| ISSUE-006: No vulnerability scanning | CRITICAL | Task 7 |
| ISSUE-007: No Helm validation | CRITICAL | Task 8 |
| ISSUE-008: Non-reproducible npm commands | HIGH | Task 2 |
| ISSUE-009: Wrong MongoDB hostname | HIGH | Task 3 |
| ISSUE-010: MongoDB probes without auth | HIGH | Task 11 |
| ISSUE-012: Hardcoded IMAGE_VERSION | HIGH | Task 6 |
| ISSUE-013: Version in 3+ places | HIGH | Task 6, 13, 14 |
| ISSUE-014: Fork PR login fails | HIGH | Task 6 |
| ISSUE-015: No PodDisruptionBudget | HIGH | Task 12 |
| ISSUE-016: No NetworkPolicy | HIGH | Task 12 |
| ISSUE-017: No Ingress support | HIGH | Deferred to Phase 3 |
| ISSUE-018: Incomplete security contexts | HIGH | Task 10, 11 |
| ISSUE-019: UI-only healthcheck | HIGH | Task 4 |
| ISSUE-020: Password in process table | HIGH | Task 5 |
| ISSUE-022: Hardcoded NBI port | HIGH | Task 9, 10 |
| ISSUE-023: Makefile buildx no artifact | HIGH | Task 14 |
| ISSUE-024: MongoDB password in ps | HIGH | Task 4 |
| ISSUE-025: No K8s manifest validation | HIGH | Deferred to Phase 4 |
| ISSUE-026: ServiceAccount not wired | HIGH | Task 10, 12 |
| ISSUE-048: License boilerplate | LOW | Task 1 |
