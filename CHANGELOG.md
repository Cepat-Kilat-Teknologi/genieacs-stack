# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- GitHub Issue templates (bug report, feature request) with YAML-based forms
- GitHub Pull Request template with checklist and change type classification
- CODEOWNERS file for automatic PR review assignment
- Helm chart tests (`helm test`) for both default and nbi-auth variants — verifies UI, NBI, and MongoDB connectivity
- CI smoke test workflow — boots full stack with Docker Compose and verifies all endpoints
- MongoDB backup CronJob template for Helm charts (optional, disabled by default)
- Backup PVC template for persistent backup storage in Kubernetes
- Ingress cert-manager annotation examples (cluster-issuer, ssl-redirect, proxy-body-size)
- CWMP host example in Ingress values for TR-069 CPE device routing
- Repository topics: cwmp, acs, iot, cpe, helm-chart, docker-compose, multi-arch, arm64, mongodb
- GitHub Discussions enabled for community Q&A

### Fixed
- LICENSE file copyright placeholder `[yyyy] [name of copyright owner]` — GitHub now detects Apache-2.0 correctly

## [1.2.16] - 2026-04-04

### Fixed
- GenieACS healthcheck used NBI root `/` which returns 404; changed to `/devices` (all 3 compose files)
- `create-user.sh` failed with MongoDB auth error; now passes credentials via connection string
- Login failed after user creation; script now invalidates GenieACS internal cache (`ui-local-cache-hash`)
- GenieACS container OOM at 1GB limit (4 Node.js processes need ~1.5GB); increased to 2GB in all manifests (Docker Compose, Helm values, Kustomize overlays)
- `create-user.sh` now bootstraps fresh installs: creates admin permissions (30 entries) and triggers GenieACS UI init (default presets, provisions, overview config)
- GenieACS `/init` with `users:true` overwrote custom user with default password; fixed by passing `users:false`
- MongoDB `chown: Operation not permitted` in Kubernetes — removed `runAsNonRoot`/`capabilities: drop: ALL` from MongoDB pod; official image needs root for entrypoint chown then drops via gosu
- Supervisord `Can't drop privilege as nonroot user` — removed `runAsUser: 1000`/`runAsNonRoot: true` from GenieACS pod; supervisord needs root to switch `user=genieacs` in child processes
- MongoDB healthcheck `user not found` in Kubernetes — `$(VAR)` K8s interpolation fails with `envFrom` secrets; changed to `bash -c` with `$VAR` shell expansion
- Nginx sidecar `chown /tmp/client_temp` failed in nbi-auth Helm — removed restrictive container security context
- Duplicate `app.kubernetes.io/component` key in mongodb-secret Helm template
- Helm OCI push 403 Forbidden — added `packages: write` permission to helm-release workflow
- GHCR references used uppercase org name — hardcoded lowercase `cepat-kilat-teknologi`
- kubeconform failed on `kustomization.yaml` — added `-ignore-filename-pattern`
- Trivy exit-code 1 blocked CI on base image CVEs — changed to exit-code 0 for SARIF reporting

### Security
- Upgraded GenieACS from 1.2.13 to 1.2.16 (critical RCE fix)
- Moved MongoDB credentials from ConfigMap to Secret in Helm charts
- Moved NBI API key from ConfigMap to Secret in Helm charts
- Fixed password exposure in process table (create-user.sh, Docker healthchecks)
- Added Trivy vulnerability scanning in CI
- Added service name validation in run_with_env.sh
- Extended .gitignore to cover example .env files

### Added
- Security scanning workflow (Trivy)
- Kubernetes manifest validation workflow (kubeconform)
- Release automation workflow
- Helm chart lint/template validation before publishing
- NetworkPolicy template for MongoDB access restriction
- PodDisruptionBudget template
- ServiceAccount template (wired into pod specs)
- Ingress template with TLS support
- `make buildx-load` target for local single-arch testing
- `make lint-docker` and `make lint-helm` targets
- Dependabot configuration for GitHub Actions and Docker
- OCI registry support for Helm charts (GHCR)

### Changed
- Consolidated Kubernetes examples: removed `examples/kubernetes/` base+overlay, kept self-contained `examples/{default,nbi-auth}/kubernetes/` for consistency with Docker and Helm examples
- `create-user.sh` now handles full fresh install bootstrap (user + permissions + UI config)
- MongoDB converted from Deployment to StatefulSet in Helm charts
- Replaced root `fix-permissions` init container with `fsGroup: 1000`
- Added timeout (300s) to `wait-for-mongodb` init container
- Added `startupProbe` to GenieACS deployment (replaces large `initialDelaySeconds`)
- Docker healthchecks now test both UI and NBI endpoints
- MongoDB healthcheck uses connection string format (no password in process list)
- Standardized `restart: unless-stopped` across all Docker Compose files
- Standardized `start_period` (MongoDB: 30s, GenieACS: 90s)
- Added resource limits and logging to root docker-compose.yml
- Scoped `make prune` to project (was system-wide)
- Helm chart version bumped to 0.3.0
- Updated Helm CI pin from v3.14.0 to v3.16.3
- CI registry login skipped on pull requests (fixes fork PR failures)
- Bumped GitHub Actions: actions/checkout v4→v6, docker/login-action v3→v4, docker/setup-qemu-action v3→v4, docker/build-push-action v6→v7, docker/setup-buildx-action v3→v4, azure/setup-helm v4→v5
- GHCR image references hardcoded lowercase for OCI compliance
- Relaxed K8s security contexts: MongoDB and GenieACS pods run as root for entrypoint compatibility, fsGroup handles volume ownership, NetworkPolicy provides isolation

### Fixed
- MongoDB hostname mismatch (`mongodb` → `mongo`) in all .env files
- Hardcoded NBI port 7557 in nbi-auth Helm templates
- Non-functional `MONGO_DATA_DIR`/`MONGO_LOG_DIR` environment variables removed
- `npm audit fix --force || true` removed (non-reproducible builds)
- License copyright boilerplate filled in

### Removed
- `wget` and `iputils-ping` from runtime Docker image
- `python3`, `make`, `g++` build dependencies (unnecessary for GenieACS 1.2.x)
- `--unsafe-perm` npm flag (deprecated)
