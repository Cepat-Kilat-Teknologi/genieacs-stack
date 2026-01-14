FROM node:24-bookworm AS build

# Install build dependencies
RUN apt-get update \
 && apt-get install -y python3 make g++ \
 && rm -rf /var/lib/apt/lists/*

# Install GenieACS from npm (pre-built, no build step needed)
WORKDIR /opt/genieacs
ARG GENIEACS_VERSION=1.2.13
RUN npm install --unsafe-perm genieacs@${GENIEACS_VERSION}

##################################
# -------- Final image ----------#
##################################
FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      supervisor ca-certificates iputils-ping logrotate curl wget \
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