# Build stage
FROM node:lts-slim AS build
LABEL maintainer="info@ckt.co.id"

# Install build dependencies and ca-certificates
RUN apt-get update \
 && apt-get install -y --no-install-recommends git make g++ ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Install GenieACS
WORKDIR /opt
ARG GENIEACS_VERSION=v1.2.13
RUN git clone --depth 1 --single-branch \
      --branch "${GENIEACS_VERSION}" \
      https://github.com/genieacs/genieacs.git

WORKDIR /opt/genieacs
# Install dependencies and ensure fixed versions of vulnerable packages
RUN npm ci --unsafe-perm \
 && npm install koa@2.16.1 cross-spawn@7.0.5 path-to-regexp@6.3.0 micromatch@4.0.8 brace-expansion@2.0.2 --save-exact \
 && npm audit fix --force \
 && npm run build

# Services stage
FROM debian:stable-slim AS services
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /tmp
RUN git clone --depth 1 --single-branch --branch 1.2.13 \
      https://github.com/GeiserX/genieacs-services.git

# Final image
FROM debian:stable-slim

# Install runtime dependencies, minimize packages
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      supervisor ca-certificates iputils-ping logrotate \
      libpam0g \
 && apt-get upgrade -y \
 && rm -rf /var/lib/apt/lists/*

# Copy Node runtime and GenieACS artefacts from the build stage
COPY --from=build /usr/local /usr/local
COPY --from=build /opt/genieacs /opt/genieacs

# Copy supervisor and helper scripts
COPY --from=services /tmp/genieacs-services/supervisord.conf \
     /etc/supervisor/conf.d/genieacs.conf
COPY --from=services /tmp/genieacs-services/run_with_env.sh \
     /usr/local/bin/run_with_env.sh
RUN chmod +x /usr/local/bin/run_with_env.sh

# Copy logrotate rule
COPY genieacs.logrotate /etc/logrotate.d/genieacs

# Create runtime user
RUN useradd --system --no-create-home --home /opt/genieacs genieacs \
 && mkdir -p /opt/genieacs/ext /var/log/genieacs \
 && chown -R genieacs:genieacs /opt/genieacs /var/log/genieacs

USER genieacs
WORKDIR /opt/genieacs

EXPOSE 7547 7557 7567 3000
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/genieacs.conf"]