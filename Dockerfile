# ==============================================================================
# GenieACS Multi-Architecture Docker Image
# ==============================================================================
# Builds a production-ready GenieACS container for linux/amd64 and linux/arm64.
# Uses a two-stage build: Node.js for compilation, Debian slim for runtime.
#
# Build:
#   docker build -t genieacs:latest .
#   docker build --build-arg GENIEACS_VERSION=1.2.16 -t genieacs:1.2.16 .
#
# Override base images in CI for exact pinning:
#   docker build --build-arg NODE_VERSION=24.12 -t genieacs:latest .
# ==============================================================================

# Base image versions — pinned for reproducibility, updated via Dependabot.
# Override in CI with --build-arg for exact version control.
ARG NODE_VERSION=24
ARG DEBIAN_VERSION=bookworm

# ------------------------------------------------------------------------------
# Stage 1: Build — Install GenieACS and its Node.js dependencies
# ------------------------------------------------------------------------------
# Uses the slim variant to minimize the /usr/local tree copied to the final image.
# No native modules (node-gyp) are needed for GenieACS 1.2.x, so build tools
# like python3, make, and g++ are intentionally omitted.
FROM node:${NODE_VERSION}-${DEBIAN_VERSION}-slim AS build

WORKDIR /opt/genieacs

# GenieACS version — change this to upgrade. All dependencies are pure JavaScript.
ARG GENIEACS_VERSION=1.2.16
RUN npm install genieacs@${GENIEACS_VERSION}

# ------------------------------------------------------------------------------
# Stage 2: Runtime — Minimal Debian image with only what GenieACS needs
# ------------------------------------------------------------------------------
FROM debian:${DEBIAN_VERSION}-slim

# Install only the packages required at runtime:
#   - supervisor: manages the 4 GenieACS processes (cwmp, nbi, fs, ui)
#   - ca-certificates: required for TLS connections to external services
#   - logrotate: rotates GenieACS log files to prevent disk exhaustion
#   - curl: used by Docker/Kubernetes health checks
RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends \
      supervisor ca-certificates logrotate curl \
 && rm -rf /var/lib/apt/lists/*

# Copy only the Node.js binary and the GenieACS installation from the build
# stage.  npm/npx/corepack are intentionally excluded — they are not needed
# at runtime (GenieACS is already installed) and removing them eliminates
# CVEs in npm's bundled dependencies (tar, minimatch, picomatch, etc.)
# that Trivy would otherwise flag.
COPY --from=build /usr/local/bin/node /usr/local/bin/node
COPY --from=build /opt/genieacs /opt/genieacs

# Supervisor configuration — defines how the 4 GenieACS services are managed.
# See config/supervisord.conf for process-level settings.
COPY config/supervisord.conf /etc/supervisor/conf.d/genieacs.conf

# Helper script that sets up the environment and launches a GenieACS service.
# Called by supervisor for each of the 4 services (cwmp, nbi, fs, ui).
COPY scripts/run_with_env.sh /usr/local/bin/run_with_env.sh
RUN chmod +x /usr/local/bin/run_with_env.sh

# Log rotation policy — prevents GenieACS logs from filling the disk.
COPY config/genieacs.logrotate /etc/logrotate.d/genieacs

# Create a non-root user for running GenieACS services.
# Supervisor itself runs as root (PID 1) but spawns all GenieACS processes
# as the 'genieacs' user (UID 1000) via the user= directive in supervisord.conf.
RUN useradd --system --no-create-home --home /opt/genieacs genieacs \
 && mkdir -p /opt/genieacs/ext /var/log/genieacs \
 && chown -R genieacs:genieacs /opt/genieacs /var/log/genieacs

WORKDIR /opt/genieacs

# GenieACS service ports:
#   7547 — CWMP (TR-069): CPE device management protocol
#   7557 — NBI: Northbound Interface REST API
#   7567 — FS: Firmware/file server for device updates
#   3000 — UI: Web-based management interface
EXPOSE 7547 7557 7567 3000

# Start supervisor in foreground mode (-n) to keep the container running.
# Supervisor manages all 4 GenieACS processes and restarts them on failure.
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/genieacs.conf"]
