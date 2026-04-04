# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- GenieACS healthcheck used NBI root `/` which returns 404; changed to `/devices` (all 3 compose files)
- `create-user.sh` failed with MongoDB auth error; now passes credentials via connection string
- Login failed after user creation; script now invalidates GenieACS internal cache (`ui-local-cache-hash`)
- GenieACS container OOM at 1GB limit (4 Node.js processes need ~1.5GB); increased to 2GB
- `create-user.sh` now bootstraps fresh installs: creates admin permissions (30 entries) and triggers GenieACS UI init (default presets, provisions, overview config)
- GenieACS `/init` with `users:true` overwrote custom user with default password; fixed by passing `users:false`

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
