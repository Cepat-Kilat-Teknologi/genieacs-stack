# GenieACS Stack — Improvement Roadmap

> Generated from deep codebase analysis on 2026-04-04.
> Organized by priority phases for making GenieACS truly multiarch/multiplatform production-ready.

---

## Phase 1: Critical Security & Stability (Must Do First)

- [ ] **Upgrade GenieACS to 1.2.16** — Fixes critical RCE vulnerability (CVE follow-up in 1.2.15)
  - Update `Dockerfile` ARG `GENIEACS_VERSION`
  - Update `IMAGE_VERSION` in `.github/workflows/docker-build.yml`
  - Update `appVersion` in both `Chart.yaml` files
  - Update `VERSION` in `Makefile`

- [ ] **Fix credential exposure** — Remove tracked `.env` files, extend `.gitignore`
  - `git rm --cached examples/default/docker/.env examples/nbi-auth/docker/.env`
  - Add `examples/**/.env` to root `.gitignore`
  - Consider `git filter-repo` to purge secrets from history

- [ ] **Fix MongoDB hostname mismatch** — Change `mongodb:27017` to `mongo:27017` in all 4 env files

- [ ] **Remove non-reproducible npm commands** — Delete `npm audit fix --force || true` and `npm update` from Dockerfile. Use lockfile approach instead.

- [ ] **Move secrets out of ConfigMaps (Kubernetes)** — MongoDB password and NBI API key must be in Secrets, not ConfigMaps

- [ ] **Fix license boilerplate** — Fill in copyright year and owner name

---

## Phase 2: Multiarch Docker Image Improvements

- [ ] **Optimize Dockerfile for multiarch builds**
  - Add `--platform=$BUILDPLATFORM` to build stage FROM for faster cross-compilation
  - Switch build stage to `node:24-bookworm-slim` to reduce copied artifacts
  - Remove unnecessary build deps (`python3 make g++`) or document rationale
  - Remove `--unsafe-perm` flag (deprecated in npm 7+)
  - Remove unused `wget` and `iputils-ping` from runtime image

- [ ] **Pin base image tags to digests** — `node:24-bookworm@sha256:...` in CI for immutable builds

- [ ] **Improve healthchecks** — Check all 4 GenieACS services, not just UI port 3000
  - Docker: `curl -sf http://localhost:3000/ && curl -sf http://localhost:7557/`
  - Kubernetes: Add `startupProbe` + per-service readiness checks

- [ ] **Fix MongoDB healthcheck** — Use connection string format to avoid password in process list

- [ ] **Add `supervisorctl` socket** — Enable operational control inside container

- [ ] **Document ARMv7 as unsupported** — Node.js 24 dropped official ARMv7 binaries

- [ ] **Improve `.dockerignore`** — Add `examples/`, `*.md` (except README), and Helm directories

---

## Phase 3: Kubernetes/Helm Production Hardening

- [ ] **Convert MongoDB Deployment to StatefulSet** with VolumeClaimTemplates

- [ ] **Replace `fix-permissions` init container** with pod-level `securityContext.fsGroup: 1000`

- [ ] **Add complete security contexts** for all containers
  ```yaml
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    readOnlyRootFilesystem: true  # with tmpfs for writable paths
    capabilities:
      drop: ["ALL"]
    seccompProfile:
      type: RuntimeDefault
  ```

- [ ] **Add missing Kubernetes resources**
  - [ ] Ingress template with TLS support and `ingressClassName`
  - [ ] PodDisruptionBudget template
  - [ ] NetworkPolicy restricting MongoDB access to GenieACS pods only
  - [ ] ServiceAccount creation and pod spec reference
  - [ ] HorizontalPodAutoscaler template
  - [ ] ServiceMonitor/PodMonitor for Prometheus

- [ ] **Fix Helm template bugs**
  - Hardcoded NBI port `7557` in nbi-auth deployment → use `{{ .Values.genieacs.service.ports.nbi }}`
  - Hardcoded `127.0.0.1:7557` in nginx configmap → template from values
  - Add `required` validation on all secret values
  - Add `kubeVersion` constraint to `Chart.yaml`
  - Wire `serviceAccountName` into pod specs
  - Add `imagePullSecrets` support
  - Add `topologySpreadConstraints` support

- [ ] **Add multiarch scheduling examples** in values.yaml
  ```yaml
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: kubernetes.io/arch
                operator: In
                values: [amd64, arm64]
  ```

- [ ] **Use `RollingUpdate` strategy for GenieACS** — `Recreate` causes guaranteed downtime. Only MongoDB needs `Recreate`.

- [ ] **Refactor Kustomize into base+overlay structure** — Eliminate ~80% duplication between default and nbi-auth variants

- [ ] **Fix MongoDB auth in probes** — Pass credentials for authenticated clusters

---

## Phase 4: CI/CD Pipeline Enhancements

- [ ] **Add security scanning workflow** — Trivy image + config scan, SARIF upload, fail on HIGH/CRITICAL

- [ ] **Add Helm chart testing** — `helm lint`, `helm template`, `ct lint` before publishing

- [ ] **Add Kubernetes manifest validation** — `kubeconform` for all YAML files

- [ ] **Fix CI login for fork PRs** — Conditional login to prevent fork PR failures

- [ ] **Implement single source of truth for versions** — Derive all versions from Git tags via release automation

- [ ] **Add cosign image signing** — Keyless Sigstore/cosign alongside existing GitHub attestations

- [ ] **Add registry cache backend** — `cache-from: type=registry` for cross-PR cache hits

- [ ] **Consider native ARM runners** — Matrix build with `ubuntu-24.04-arm` for faster arm64 builds

- [ ] **Add path filters to CI triggers** — Avoid full Docker rebuilds on documentation-only changes

- [ ] **Upgrade Helm pin** — `v3.14.0` → current stable (3.16+)

- [ ] **Add OCI registry support** — `helm push` to GHCR alongside GitHub Pages

- [ ] **Add Dependabot/Renovate** — Monitor Actions, Docker images, npm, and Helm dependencies

---

## Phase 5: Docker Compose Standardization

- [ ] **Standardize all 3 compose files**
  - `restart: unless-stopped` (not `always`)
  - Consistent `start_period` (MongoDB 30s, GenieACS 90s)
  - Resource limits and logging on root compose (matching examples)
  - Unique volume name prefixes per deployment context
  - Docker Compose v2 compatibility comments

- [ ] **Resolve ext volume inconsistency** — Decide bind-mount vs named volume, document rationale

- [ ] **Remove unused env vars from `.env.example`** or add them to compose `environment:` blocks

- [ ] **Add env var validation to `make setup`** — Warn when placeholder secrets remain

---

## Phase 6: Documentation & Developer Experience

- [ ] **Add ARM64 deployment guide** — MongoDB 8.0 requirements, Raspberry Pi notes, Apple Silicon quirks

- [ ] **Fix INSTALLATION.md `sed -i` commands** — Provide both macOS and Linux variants

- [ ] **Add system architecture diagram** — CWMP/NBI/FS/UI/MongoDB/nginx interconnections

- [ ] **Create CHANGELOG.md** with conventional commits + automated generation

- [ ] **Create CONTRIBUTING.md** — Code style, test requirements, Helm versioning, review process

- [ ] **Add Makefile targets**
  - `make lint-docker` — Hadolint
  - `make lint-helm` — `helm lint` both charts
  - `make helm-template` — Render templates locally
  - `make buildx-load` — Single-arch local testing with `--load`
  - `make release` — Atomic version bump + tag
  - `make kubeconform` — Validate Kubernetes manifests

- [ ] **Fix `make prune` scope** — Project-scoped cleanup, not system-wide

- [ ] **Fix `create-user.sh` security** — Stdin password passing, proper escaping, jq for JSON parsing

- [ ] **Fix `run_with_env.sh`** — Add service name whitelist validation

---

## Phase 7: Future Enhancements

- [ ] **Consider ARM/v7 support** — Offer Node.js 22 LTS variant for 32-bit ARM devices
- [ ] **Consider Operator pattern** — Replace Helm chart with Kubernetes Operator for lifecycle management
- [ ] **Add `read_only: true`** container mode with proper tmpfs mounts for writable paths
- [ ] **Helm chart dependency** — Use Bitnami MongoDB sub-chart instead of hand-rolled deployment
- [ ] **Multi-cluster ArgoCD** — Document external cluster targeting for GitOps
- [ ] **Add Grafana dashboard** — Pre-built monitoring dashboard for GenieACS metrics
