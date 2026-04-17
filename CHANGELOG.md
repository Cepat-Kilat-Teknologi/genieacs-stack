# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] (v1.3.0 in progress — ISP SaaS preset bundle)

### Added — ZTE F670L WAN PON optical paths

After real-lab verification against a ZTE F670L (V9.0.10P1N12A), the
preset bundle now declares 6 additional retention paths under
`InternetGatewayDevice.WANDevice.1.X_ZTE-COM_WANPONInterfaceConfig.*`.
These feed the **genieacs-relay v2.2.0 optical handler's new F670L
extractor** (see genieacs-relay CHANGELOG v2.2.0). Without these
entries the optical endpoint returns `404 OPTICAL_NOT_SUPPORTED` on
F670L because GenieACS only fetches subtrees declared in an active
preset; the F670L does not expose the five existing `X_CT-COM_*` /
`X_HW_DEBUG` / `X_Realtek_*` / `Device.Optical.*` trees that older
vendor extractors rely on.

New entries (`type=age`, age 300s):
- `...X_ZTE-COM_WANPONInterfaceConfig.TXPower`
- `...X_ZTE-COM_WANPONInterfaceConfig.RXPower`
- `...X_ZTE-COM_WANPONInterfaceConfig.BiasCurrent`
- `...X_ZTE-COM_WANPONInterfaceConfig.TransceiverTemperature`
- `...X_ZTE-COM_WANPONInterfaceConfig.SupplyVoltage` (millivolts — the
  relay normalizes `>100` raw to volts automatically)
- `...X_ZTE-COM_WANPONInterfaceConfig.Status`

Real-lab verification via genieacs-relay `GET /optical/{ip}`:
TX 2.59 dBm, RX -25.08 dBm, bias 13.7 mA, temp 35.31°C, V 3.244,
source `zte_wan_pon_interface`.

### Known issue — stock `inform` provision atomic rollback on ZTE

**Not caused by this preset, but surfaced during the same lab session.**
GenieACS's built-in `/init` bootstrap creates an `inform` provision
that writes `PeriodicInformTime` as numeric ms-since-epoch via
`declare(... {value: informTime})`. ZTE F670L (and likely other ZTE
OEM firmware lines) expects `xsd:dateTime` ISO 8601 and rejects the
numeric with fault `9007 Invalid parameter value`. Because TR-069
`setParameterValues` is atomic, this rejection rolls back **every
sibling write in the same call** — including
`ConnectionRequestUsername` / `ConnectionRequestPassword`. The CPE
then holds stale credentials, GenieACS's side of the handshake
drifts, and live `?connection_request` calls fail with HTTP 401
Digest errors. Symptom: reboot / wake endpoints in the relay
succeed at the API layer (202 task enqueued) but the CPE never
receives the task because GenieACS can't authenticate to its
ConnectionRequestURL.

**Mitigation (applied live in the lab mongo, not yet
file-level)**: patch the `inform` provision in mongo to drop the
`PeriodicInformTime` declares. Leaves `PeriodicInformEnable` /
`PeriodicInformInterval` intact.

**To ship as permanent fix in v1.3.1** (tracked):
- Option A: extend `scripts/create-user.sh` with a post-`/init`
  step that rewrites the `inform` provision via mongosh.
- Option B: ship an override provision at a higher `weight` that
  runs after the stock `inform` and short-circuits the bad declare.
- Option C: upstream PR to GenieACS itself.

### Added — Preset bundle companion to genieacs-relay v2.2.0

- **`examples/default/presets/isp-saas-default.json`** — declarative
  GenieACS preset bundle that ships with 51 TR-069 parameter path
  declarations. Pairs with **genieacs-relay v2.2.0** whose new read
  endpoints (H1 `/status/{ip}`, H4 `/wan/{ip}`, M3 `/wifi-clients/{ip}`,
  M7 `/wifi-stats/{ip}`, M1/M2 diagnostic result poll paths) expect
  data richer than the default CWMP inform payload. Without the
  preset, those endpoints return empty or incomplete device trees
  because GenieACS only retains parameters that are declared in an
  active preset or provision — a well-known behavior of the upstream
  GenieACS server, not a genieacs-stack bug.

  Preset coverage groups (see
  `examples/default/presets/README.md` for the full rationale table):

  | Group | Paths | Age (s) | Consumer |
  |---|---|---|---|
  | DeviceInfo (identification) | Manufacturer, ModelName, HardwareVersion, SerialNumber | 86400 | H1 status + M5 devices/search |
  | DeviceInfo (version) | SoftwareVersion | 3600 | H1 status |
  | DeviceInfo (live) | UpTime | 60 | H1 status |
  | WAN PPP connection | ConnectionStatus, ExternalIPAddress, Username, Uptime, LastConnectionError | 60-300 | H4 wan |
  | WAN IP connection | ConnectionStatus, ExternalIPAddress, Uptime, AddressingType | 60-3600 | H4 wan |
  | Associated WiFi clients | AssociatedDeviceMACAddress, {X_,}SignalStrength, AuthenticationState | 60 | M3 wifi-clients |
  | WiFi radio config | Channel, TransmitPower, X_TXPower | 300 | M7 wifi-stats |
  | WiFi radio stats | Total{Bytes,Packets}{Sent,Received}, Errors{Sent,Received} | 60 | M7 wifi-stats |
  | IPPingDiagnostics results | DiagnosticsState, {Success,Failure}Count, {Avg,Min,Max}ResponseTime | 30 | M1 diag/ping result poll |
  | TraceRouteDiagnostics results | DiagnosticsState, ResponseTime, RouteHopsNumberOfEntries, RouteHops.* | 30 | M2 diag/traceroute result poll |
  | WLAN MAC filter verify | WLANAccessControlMode, WLANAccessControlEntry.*.MACAddress | 300 | L5 mac-filter readback |
  | Port forwarding verify | PortMapping.*.{PortMappingEnabled,Protocol,ExternalPort,InternalClient,InternalPort,Description} | 300 | L1 port-forwarding readback |
  | Static DHCP verify | DHCPStaticAddress.*.{Enable,Chaddr,Yiaddr} | 300 | L6 static-dhcp readback |

  Vendor-specific extension paths (`X_SignalStrength`, `X_TXPower`)
  are declared alongside their standard-path equivalents so the relay
  falls back gracefully across the Indonesian ONT fleet (ZTE F670L,
  Huawei EG8145V5, FiberHome HG6243C, etc.). Devices that don't expose
  a particular path simply produce empty values in the device tree —
  no hard errors.

- **`examples/default/presets/README.md`** — install guide, rationale
  table, vendor caveats, and uninstall procedure. Three install paths
  documented: (1) via genieacs-relay v2.2.0+ `PUT /presets/{name}`
  endpoint (recommended — full-circle dogfooding of the relay's own
  L10 endpoint), (2) direct `PUT /presets/{id}` against the GenieACS
  NBI, (3) manual paste into the GenieACS Web UI at Admin → Presets.

### Compatibility

- **genieacs-stack v1.3.0 ↔ genieacs-relay v2.2.0** is the recommended
  paired release. v1.2.16 + relay v2.1.x continues to work for the
  v2.1.0 endpoint set (reboot, DHCP refresh, optical health, WLAN CRUD)
  since those only depend on default inform fields.
- **No stack code changes** — this release is pure config bundle + docs.
  MongoDB 8.0 and GenieACS 1.2.16 versions unchanged.

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

### Security
- Removed npm/npx/corepack from runtime image — eliminates 5 CVEs in npm bundled deps (tar, minimatch, picomatch)

### Fixed
- LICENSE file copyright placeholder `[yyyy] [name of copyright owner]` — GitHub now detects Apache-2.0 correctly
- CI docker-build GHCR registry cache 401 on PRs — cache-from/cache-to now conditional on non-PR events

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
