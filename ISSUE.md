# GenieACS Stack — Issue Register

> Generated from deep codebase analysis on 2026-04-04.
> Issues are categorized by severity and area. Each issue includes affected files and recommended fix.

---

## CRITICAL Issues

### ISSUE-001: GenieACS 1.2.13 Has Known Critical RCE Vulnerability

- **Area:** Security / Dockerfile
- **Files:** `Dockerfile:11`, `.github/workflows/docker-build.yml:12`
- **Description:** GenieACS 1.2.13 contains a critical Remote Code Execution vulnerability that was fixed in 1.2.15 (follow-up to CVE-2021-46704). The current `GENIEACS_VERSION=1.2.13` ARG and the hardcoded `IMAGE_VERSION: '1.2.13'` in CI both pin to the vulnerable version.
- **Fix:** Upgrade `GENIEACS_VERSION` to `1.2.16` (latest stable) in Dockerfile and update `IMAGE_VERSION` in CI workflow.

---

### ISSUE-002: `.env` Files with Real Credentials Committed to Repository

- **Area:** Security
- **Files:**
  - `examples/default/docker/.env` — contains real 64-char hex JWT secret
  - `examples/nbi-auth/docker/.env` — contains real JWT secret and API key
  - `.env` — contains weak but real credentials (`kmzway87aa`, `password123`, `admin123`)
- **Description:** The root `.gitignore` excludes `.env` but there are no `.gitignore` files in `examples/*/docker/` directories. The subdirectory `.env` files are tracked by git with real credentials.
- **Fix:**
  1. `git rm --cached examples/default/docker/.env examples/nbi-auth/docker/.env`
  2. Add `examples/**/.env` to root `.gitignore`
  3. Rotate all secrets that appeared in git history
  4. Consider `git filter-repo` to purge secrets from history

---

### ISSUE-003: MongoDB Password Stored in Plaintext ConfigMap (Kubernetes/Helm)

- **Area:** Security / Kubernetes
- **Files:**
  - `examples/default/kubernetes/configmap.yaml:12`
  - `examples/default/helm/genieacs/templates/configmap.yaml:11`
  - `examples/nbi-auth/helm/genieacs/templates/configmap.yaml`
- **Description:** The `GENIEACS_MONGODB_CONNECTION_URL` containing the MongoDB password is stored in a ConfigMap, not a Secret. ConfigMaps are not encrypted at rest, not subject to Secret RBAC, and visible to any pod with `get configmap` permission.
- **Fix:** Move `GENIEACS_MONGODB_CONNECTION_URL` to a Secret, or construct the URL at runtime from separate secret-sourced environment variables.

---

### ISSUE-004: NBI API Key Stored in Plaintext ConfigMap (nbi-auth)

- **Area:** Security / Kubernetes
- **Files:**
  - `examples/nbi-auth/kubernetes/nginx-nbi-auth.yaml:34`
  - `examples/nbi-auth/helm/genieacs/templates/nginx-configmap.yaml:41`
- **Description:** The API key is embedded literally into the nginx ConfigMap. Anyone with `get configmap` RBAC can read it. Helm renders it as `{{ .Values.nbiAuth.apiKey }}` directly into the config.
- **Fix:** Source the API key from a Kubernetes Secret and inject it via environment variable + `envsubst` at container startup.

---

### ISSUE-005: `fix-permissions` Init Container Runs as Root — Fails on PSS-Restricted Clusters

- **Area:** Security / Kubernetes
- **Files:**
  - `examples/default/kubernetes/genieacs-deployment.yaml:23-39`
  - `examples/default/helm/genieacs/templates/genieacs-deployment.yaml:38-53`
  - (Same in nbi-auth variants)
- **Description:** The `fix-permissions` init container runs `busybox` as root to `chown -R 1000:1000`. On clusters with Pod Security Standards enforced at `restricted` level, this pod will be rejected.
- **Fix:** Replace with pod-level `securityContext.fsGroup: 1000`. Kubernetes handles volume ownership automatically, eliminating the need for the init container entirely.

---

### ISSUE-006: No Automated Vulnerability Scanning in CI

- **Area:** CI/CD / Security
- **Files:** `.github/workflows/` (missing workflow)
- **Description:** No Trivy, Grype, Snyk, or Docker Scout step exists in any CI workflow. The `npm audit fix --force || true` in the Dockerfile suppresses all audit failures silently. `make scan` exists but is manual-only.
- **Fix:** Add a `security.yml` workflow with Trivy image + config scanning, upload SARIF to GitHub Security tab, fail on HIGH/CRITICAL.

---

### ISSUE-007: No Helm Chart Validation Before Publishing

- **Area:** CI/CD / Helm
- **Files:** `.github/workflows/helm-release.yml`
- **Description:** The Helm release workflow packages and publishes charts with zero validation — no `helm lint`, no `helm template` rendering test, no `ct lint`, no schema validation. A malformed chart goes straight to gh-pages.
- **Fix:** Add `helm lint` and `helm template` steps before packaging. Consider `ct lint` for comprehensive validation.

---

## HIGH Issues

### ISSUE-008: `npm audit fix --force || true` Makes Builds Non-Reproducible

- **Area:** Dockerfile / Build
- **Files:** `Dockerfile:14`, `Dockerfile:17`
- **Description:** `npm audit fix --force` ignores semver constraints and can upgrade packages across major versions. The `|| true` suppresses all errors. Combined with `npm update koa qs path-to-regexp glob tar`, builds are non-reproducible — same Dockerfile on different dates produces different `node_modules`.
- **Fix:** Remove both lines. Use a lockfile or `npm install` overrides approach for pinned, reproducible builds.

---

### ISSUE-009: Wrong MongoDB Hostname in `.env.example` Files

- **Area:** Configuration / Docker
- **Files:**
  - `.env.example:32` — uses `mongodb:27017`
  - `.env:7` — uses `mongodb:27017`
  - `examples/default/docker/.env.example:32` — uses `mongodb:27017`
  - `examples/nbi-auth/docker/.env.example:34` — uses `mongodb:27017`
- **Description:** All env files reference `mongodb` as the hostname, but the Docker Compose service name is `mongo` (line 3 of `docker-compose.yml`). This causes DNS resolution failure at runtime. The `GENIEACS_MONGODB_CONNECTION_URL` variable overrides compose-level defaults, so the wrong hostname takes effect.
- **Fix:** Change `mongodb:27017` to `mongo:27017` in all env files, or rename the compose service to `mongodb`.

---

### ISSUE-010: MongoDB Health Probes Fail with Authentication Enabled (Helm/Kustomize)

- **Area:** Kubernetes / Helm
- **Files:**
  - `examples/default/helm/genieacs/templates/mongodb-deployment.yaml:56-75`
  - `examples/default/kubernetes/mongodb-deployment.yaml:48-67`
  - (Same in nbi-auth variants)
- **Description:** Health probes run `mongosh --eval "db.adminCommand('ping')"` without credentials. When `mongodb.auth.enabled: true` (the default), this may fail with authentication errors, causing the pod to be considered unhealthy.
- **Fix:** Include credentials in probes: `mongosh -u $(MONGO_INITDB_ROOT_USERNAME) -p $(MONGO_INITDB_ROOT_PASSWORD) --authenticationDatabase admin --eval "db.adminCommand('ping')"`.

---

### ISSUE-011: MongoDB Deployed as Deployment Instead of StatefulSet

- **Area:** Kubernetes / Helm
- **Files:**
  - `examples/default/helm/genieacs/templates/mongodb-deployment.yaml`
  - `examples/default/kubernetes/mongodb-deployment.yaml`
  - (Same in nbi-auth variants)
- **Description:** MongoDB uses a `Deployment` with separate PVC. If two replicas start transiently during node failure, both may write to the same RWO PVC, causing data corruption. StatefulSet provides stable identity and ordered pod management.
- **Fix:** Convert to StatefulSet with VolumeClaimTemplates. Remove separate PVC files.

---

### ISSUE-012: `IMAGE_VERSION` Hardcoded in CI — Creates Stale Tags

- **Area:** CI/CD
- **Files:** `.github/workflows/docker-build.yml:12`
- **Description:** `IMAGE_VERSION: '1.2.13'` is decoupled from Git tags. When `v1.2.14` is pushed, the workflow pushes both the correct semver tag AND the stale `1.2.13` raw tag simultaneously.
- **Fix:** Remove `IMAGE_VERSION` raw tag. Derive version solely from Git tags via `docker/metadata-action` semver rules.

---

### ISSUE-013: Version Defined in 3+ Places with No Single Source of Truth

- **Area:** Build / Maintenance
- **Files:**
  - `Makefile:7` — `VERSION = v1.2.13`
  - `.github/workflows/docker-build.yml:12` — `IMAGE_VERSION: '1.2.13'`
  - `examples/default/helm/genieacs/Chart.yaml:6` — `appVersion: "1.2.13"`
  - `examples/nbi-auth/helm/genieacs/Chart.yaml:6` — `appVersion: "1.2.13"`
- **Description:** Four separate hardcoded version definitions. A version bump requires editing at minimum 4 files manually. There is no automation to keep them in sync.
- **Fix:** Implement a release workflow that reads version from a single source (e.g., Git tag) and propagates to all files.

---

### ISSUE-014: CI Login Steps Fail on Fork PRs

- **Area:** CI/CD
- **Files:** `.github/workflows/docker-build.yml:45-58`
- **Description:** Docker Hub and GHCR login steps run unconditionally, including on PRs from forks. Fork PR workflows cannot access repository secrets, causing login failure that aborts the entire workflow.
- **Fix:** Add condition: `if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository`.

---

### ISSUE-015: No PodDisruptionBudget in Kubernetes Manifests

- **Area:** Kubernetes / Helm
- **Files:** Both Helm charts and Kustomize manifests (missing resource)
- **Description:** No PDB defined. With `replicaCount: 1`, a `kubectl drain` during cluster upgrade terminates GenieACS with no protection.
- **Fix:** Add PDB template with `minAvailable: 1` for multi-replica deployments.

---

### ISSUE-016: No NetworkPolicy — MongoDB Accessible from Any Pod

- **Area:** Kubernetes / Security
- **Files:** Both Helm charts and Kustomize manifests (missing resource)
- **Description:** No NetworkPolicy restricts access. Any pod in the namespace (or cluster) can reach MongoDB on port 27017. CWMP port is not restricted to CPE device subnets.
- **Fix:** Add NetworkPolicy template restricting MongoDB ingress to only the GenieACS pod.

---

### ISSUE-017: No Ingress Support in Helm Charts

- **Area:** Kubernetes / Helm
- **Files:** Both Helm charts (missing template)
- **Description:** No Ingress resource exists. The only exposure mechanism is LoadBalancer/NodePort. Production deployments require Ingress for TLS termination and hostname routing. README mentions "Enable TLS with Ingress" but provides zero implementation.
- **Fix:** Add Ingress template with `ingressClassName`, TLS secret reference, and annotation support.

---

### ISSUE-018: Incomplete Container Security Contexts

- **Area:** Kubernetes / Security
- **Files:** All deployment templates in both Helm charts and Kustomize manifests
- **Description:** Containers only set `allowPrivilegeEscalation: false`. Missing: `readOnlyRootFilesystem`, `capabilities: drop: ["ALL"]`, `runAsNonRoot`, `runAsUser`, `seccompProfile`. Nginx sidecar in nbi-auth has zero security context.
- **Fix:** Add complete security contexts for all containers. Add pod-level `securityContext` with `fsGroup`, `runAsUser`, `runAsNonRoot`.

---

### ISSUE-019: Healthcheck Only Tests UI Port — Partial Service Degradation Undetected

- **Area:** Docker / Kubernetes
- **Files:**
  - `docker-compose.yml:68` — `curl -f http://localhost:3000/`
  - All Helm/Kustomize deployment templates
- **Description:** GenieACS runs 4 services (CWMP, NBI, FS, UI) via supervisord. Health checks only verify the UI (port 3000). If CWMP/NBI/FS crash, the container/pod reports healthy.
- **Fix:** Add checks for critical services: `curl -sf http://localhost:3000/ && curl -sf http://localhost:7557/`.

---

### ISSUE-020: `create-user.sh` Exposes Password in Process Table

- **Area:** Security / Scripts
- **Files:** `scripts/create-user.sh:57,65`
- **Description:** Password is passed as a CLI argument to `node -e`, visible via `ps aux`. Additionally, SALT/HASH variables are injected unescaped into `mongosh --eval` (lines 88-104), risking command injection.
- **Fix:** Pass password via stdin or environment variable. Escape shell variables before mongosh injection.

---

### ISSUE-021: NBI Port 7557 Exposed Without Authentication (Default Variant)

- **Area:** Security / Kubernetes
- **Files:** `examples/default/kubernetes/genieacs-service.yaml:18-22`
- **Description:** LoadBalancer service exposes NBI API directly with no authentication. Any entity with network access can make unauthenticated API calls, read device configurations, and execute commands on CPE devices.
- **Fix:** Document the risk prominently. Recommend nbi-auth variant for production. Consider adding NetworkPolicy to restrict NBI access.

---

### ISSUE-022: Hardcoded NBI Port `7557` in nbi-auth Helm Template

- **Area:** Helm / Bug
- **Files:**
  - `examples/nbi-auth/helm/genieacs/templates/genieacs-deployment.yaml:87` — `containerPort: 7557`
  - `examples/nbi-auth/helm/genieacs/templates/nginx-configmap.yaml:45` — `proxy_pass http://127.0.0.1:7557`
- **Description:** All other ports use `{{ .Values.genieacs.service.ports.* }}` but NBI is hardcoded. Changing the port in values breaks the deployment silently.
- **Fix:** Change to `containerPort: {{ .Values.genieacs.service.ports.nbi }}` and `proxy_pass http://127.0.0.1:{{ .Values.genieacs.service.ports.nbi }}`.

---

### ISSUE-023: Makefile `buildx` Target Produces No Usable Artifact

- **Area:** Build / Makefile
- **Files:** `Makefile:64`
- **Description:** `make buildx` builds a multiplatform manifest but without `--load` or `--push`, the image only exists in the Buildx cache. Not usable via `docker run` or `docker images`. Silently succeeds but produces nothing.
- **Fix:** Add a `buildx-load` target for local single-arch testing with `--load` flag.

---

### ISSUE-024: MongoDB Healthcheck Exposes Password in Process List (Docker)

- **Area:** Security / Docker
- **Files:** `docker-compose.yml:23`, `examples/default/docker/docker-compose.yml:29`, `examples/nbi-auth/docker/docker-compose.yml:27`
- **Description:** `mongosh -u ... -p ${MONGO_INITDB_ROOT_PASSWORD}` makes the password visible in `ps aux` and Docker inspect output.
- **Fix:** Use connection string format: `mongosh 'mongodb://user:pass@localhost:27017/admin?authSource=admin' --eval "db.adminCommand('ping')"`.

---

### ISSUE-025: No Kubernetes Manifest Validation in CI

- **Area:** CI/CD
- **Files:** `.github/workflows/` (missing workflow)
- **Description:** Raw Kubernetes YAML manifests in `examples/*/kubernetes/` are never validated. Broken manifests reach users unchecked.
- **Fix:** Add `kubeconform` validation step in CI for all YAML files.

---

### ISSUE-026: ServiceAccount Defined But Never Referenced in Pod Specs

- **Area:** Kubernetes / Helm
- **Files:** Both Helm charts — `values.yaml` has `serviceAccount.create` but no template references it in pod specs
- **Description:** The `serviceAccountName` helper in `_helpers.tpl` is never used in any deployment template. `serviceAccount.annotations` (needed for IRSA/Workload Identity) has zero effect.
- **Fix:** Add `serviceAccountName: {{ include "genieacs.serviceAccountName" . }}` to pod specs.

---

## MEDIUM Issues

### ISSUE-027: `no-new-privileges:true` May Conflict with Supervisord's setuid

- **Files:** `docker-compose.yml:75`, `config/supervisord.conf:2`
- **Description:** Supervisord runs as root and uses setuid to spawn processes as `genieacs` user. `no-new-privileges:true` prevents setuid operations on some kernel configurations.
- **Fix:** Test explicitly on arm64. If broken, restructure to use `--cap-add=SYS_SETUID`.

---

### ISSUE-028: Floating Base Image Tags — No Digest Pinning

- **Files:** `Dockerfile:1,22`
- **Description:** `node:24-bookworm` and `debian:bookworm-slim` use floating tags. A compromised upstream image silently changes the build.
- **Fix:** Pin to digest in CI: `FROM node:24-bookworm@sha256:...`.

---

### ISSUE-029: `wget` Installed But Never Used in Runtime Image

- **Files:** `Dockerfile:28`
- **Description:** `wget` is installed in the runtime image but never referenced anywhere. Increases attack surface.
- **Fix:** Remove `wget` from `apt-get install`.

---

### ISSUE-030: Main Docker Compose Missing Resource Limits and Logging

- **Files:** `docker-compose.yml`
- **Description:** Root compose has no `deploy.resources` or `logging` config. Example composes have both. A runaway process can consume all host memory.
- **Fix:** Add resource limits and `json-file` logging matching the examples.

---

### ISSUE-031: Inconsistent `restart` Policy Between Compose Files

- **Files:** Root compose (`unless-stopped`) vs examples (`always`)
- **Description:** `restart: always` restarts containers even after deliberate `docker stop`, which is operationally surprising.
- **Fix:** Standardize on `restart: unless-stopped` across all files.

---

### ISSUE-032: Inconsistent `start_period` Between Compose Files

- **Files:** Root: MongoDB 20s / GenieACS 60s. Examples: MongoDB 30s / GenieACS 90s.
- **Description:** Shorter start_period in root compose causes spurious health failures, especially on ARM64 where startup is slower.
- **Fix:** Standardize on 30s (MongoDB) and 90s (GenieACS) across all files.

---

### ISSUE-033: `sed -i ''` Commands in INSTALLATION.md are macOS-Only

- **Files:** `INSTALLATION.md` (lines 90-92, 128-131, 171-178, 210-219)
- **Description:** `sed -i ''` is BSD/macOS-specific. On GNU/Linux (the primary production platform), this produces wrong output.
- **Fix:** Provide both macOS and Linux variants or use a cross-platform alternative.

---

### ISSUE-034: No ARM-Specific Deployment Documentation

- **Files:** `README.md`, `INSTALLATION.md`
- **Description:** ARM64 support is advertised (badges, CI builds `linux/arm64`) but there are no ARM-specific notes — MongoDB 8.0 AVX requirements, Raspberry Pi considerations, Apple Silicon Docker Desktop quirks.
- **Fix:** Add an ARM64 deployment section in INSTALLATION.md.

---

### ISSUE-035: No `topologySpreadConstraints` Support in Helm Templates

- **Files:** Both Helm charts — `values.yaml`, deployment templates
- **Description:** Templates have `nodeSelector`/`tolerations`/`affinity` wiring but no `topologySpreadConstraints`. Multi-zone/multi-arch scheduling is impossible without template changes.
- **Fix:** Add `topologySpreadConstraints` to deployment templates, with example values.

---

### ISSUE-036: No `imagePullSecrets` Support in Helm Charts

- **Files:** Both Helm charts
- **Description:** No mechanism to configure `imagePullSecrets` for private registries.
- **Fix:** Add `imagePullSecrets` field to values and reference in pod specs.

---

### ISSUE-037: `MONGO_DATA_DIR`/`MONGO_LOG_DIR` Env Vars Are Non-Functional

- **Files:** Helm/Kustomize mongodb-deployment.yaml
- **Description:** These are not official MongoDB image variables. They have no effect and create false confidence.
- **Fix:** Remove or replace with actual MongoDB config.

---

### ISSUE-038: `make prune` is Dangerously System-Wide

- **Files:** `Makefile:203-205`
- **Description:** `docker system prune -f` and `docker volume prune -f` affect ALL Docker resources, not just this project. Destructive on shared dev machines.
- **Fix:** Scope to project: `docker compose down --rmi local --volumes --remove-orphans`.

---

### ISSUE-039: No `required` Validation on Secret Values in Helm

- **Files:** Both Helm charts — `secret.yaml`, `mongodb-secret.yaml`
- **Description:** Placeholder secrets deploy silently. Users who forget to set values deploy with `"changeme-generate-with-openssl-rand-hex-32"`.
- **Fix:** Add `{{ required "secret.jwtSecret must be set" .Values.secret.jwtSecret }}` validation.

---

### ISSUE-040: No Base+Overlay Kustomize Structure

- **Files:** `examples/default/kubernetes/`, `examples/nbi-auth/kubernetes/`
- **Description:** ~80% content duplication between variants. Any fix must be applied twice independently.
- **Fix:** Refactor into `base/` + `overlays/default` + `overlays/nbi-auth`.

---

### ISSUE-041: `run_with_env.sh` Does Not Validate SERVICE Name

- **Files:** `scripts/run_with_env.sh:23`
- **Description:** Executes `/opt/genieacs/node_modules/.bin/$SERVICE` without restricting to valid service names. Misconfiguration could execute arbitrary binaries.
- **Fix:** Add whitelist: `case "$SERVICE" in genieacs-cwmp|genieacs-nbi|genieacs-fs|genieacs-ui) ;; *) exit 1 ;; esac`.

---

### ISSUE-042: Volume Name Collisions Between Root and Example Compose

- **Files:** `docker-compose.yml:83-84`, `examples/default/docker/docker-compose.yml:113-114`
- **Description:** `genieacs-app-data` and `genieacs-logs` volume names are identical. Running both on the same Docker host causes shared state; `docker compose down -v` from one destroys the other's data.
- **Fix:** Use unique prefixes per deployment context.

---

### ISSUE-043: Ext Volume Mount Inconsistency

- **Files:** Root compose (`./ext:/opt/genieacs/ext:ro`) vs examples (named volume `genieacs_ext`)
- **Description:** Architectural inconsistency. Bind mount is `:ro` but extensions may need to write. Windows hosts handle bind paths differently.
- **Fix:** Decide on one approach. Document if bind-mount is intentional for development.

---

### ISSUE-044: `GENIEACS_JWT_EXPIRES_IN` and Other Env Vars Not Forwarded

- **Files:** `.env.example:43,49,63`, all compose files
- **Description:** `GENIEACS_JWT_EXPIRES_IN`, `GENIEACS_HOST`, `GENIEACS_ALLOW_INSECURE` are documented in `.env.example` but never appear in any compose `environment:` block — silently ignored.
- **Fix:** Either add to compose `environment:` blocks or remove from `.env.example`.

---

### ISSUE-045: No OCI Registry Support for Helm Charts

- **Files:** `.github/workflows/helm-release.yml`
- **Description:** Uses traditional `helm repo index` + GitHub Pages. Modern Helm 3.8+ supports OCI registries (`helm push` to GHCR), which is the current best practice.
- **Fix:** Add `helm push` to GHCR as an additional distribution channel.

---

### ISSUE-046: No Changelog or Release Automation

- **Files:** Repository root (missing files/workflows)
- **Description:** No `CHANGELOG.md`, no conventional commit enforcement, no `release-please`/`semantic-release`. Commit messages are freeform. Release notes must be written manually.
- **Fix:** Implement conventional commits + automated changelog generation.

---

### ISSUE-047: No Dependabot/Renovate Configuration

- **Files:** `.github/` (missing `dependabot.yml`)
- **Description:** GitHub Actions, base Docker images, Helm version pin, and all dependency versions are unmonitored for updates.
- **Fix:** Add `.github/dependabot.yml` for Actions, Docker, and npm ecosystems.

---

### ISSUE-048: License File Has Unfilled Boilerplate

- **Files:** `LICENSE:189-190`
- **Description:** `Copyright [yyyy] [name of copyright owner]` — Apache 2.0 template placeholders never filled.
- **Fix:** Replace with `Copyright 2024 Cepat Kilat Teknologi`.

---

## LOW Issues

### ISSUE-049: Node.js 24 Drops ARMv7 to Experimental

- **Files:** `Dockerfile:1`
- **Description:** `node:24-bookworm` has no official ARMv7 binaries. Affects Raspberry Pi 1/Zero and older 32-bit ARM devices.
- **Note:** Document ARMv7 as unsupported, or offer Node 22 LTS variant.

---

### ISSUE-050: Build Dependencies Unnecessary for GenieACS 1.2.x

- **Files:** `Dockerfile:4-6`
- **Description:** `python3 make g++` are installed but GenieACS 1.2.x has zero native modules. These waste build time.
- **Fix:** Remove or add comment explaining they're for ext/ native addons.

---

### ISSUE-051: `--unsafe-perm` Flag Deprecated in npm 7+

- **Files:** `Dockerfile:11`
- **Fix:** Remove the flag.

---

### ISSUE-052: `.dockerignore` Missing `examples/` Directory

- **Files:** `.dockerignore`
- **Description:** `examples/` directory is sent to the build context unnecessarily.
- **Fix:** Add `examples/` to `.dockerignore`.

---

### ISSUE-053: No `supervisorctl` Socket Configured

- **Files:** `config/supervisord.conf`
- **Description:** No `[unix_http_server]` section means `supervisorctl` cannot query/restart processes inside the container.
- **Fix:** Add `[unix_http_server]` with socket path.

---

### ISSUE-054: No System Architecture Diagram

- **Files:** Documentation
- **Description:** No diagram showing how CWMP, NBI, FS, UI, MongoDB, and nginx interconnect. Critical for operators understanding traffic flows.
- **Fix:** Add architecture diagram to README or dedicated docs.

---

### ISSUE-055: No CONTRIBUTING.md

- **Files:** Repository root
- **Description:** Public production-grade project lacks contribution guidelines, code style guidance, and test requirements.
- **Fix:** Create CONTRIBUTING.md.
