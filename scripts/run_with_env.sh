#!/bin/bash
# =============================================================================
# run_with_env.sh -- Wrapper script invoked by supervisord for each GenieACS
#                    service process inside the Docker container.
# =============================================================================
#
# Usage: run_with_env.sh <service-name>
#   Services: genieacs-cwmp, genieacs-nbi, genieacs-fs, genieacs-ui
#
# Why a wrapper instead of running the binary directly?
#   Supervisord does not source shell profiles, so PATH and NODE_OPTIONS
#   need to be set explicitly before the service starts. This script
#   centralizes that setup for all four GenieACS daemons.
#
# =============================================================================

set -e

SERVICE="$1"

if [ -z "$SERVICE" ]; then
    echo "Usage: $0 <service-name>"
    echo "Services: genieacs-cwmp, genieacs-nbi, genieacs-fs, genieacs-ui"
    exit 1
fi

# --- Ensure the GenieACS binaries and system tools are on PATH ---
export PATH="/usr/local/bin:/opt/genieacs/node_modules/.bin:$PATH"

# --- Enable source maps so Node.js stack traces point to TypeScript sources ---
export NODE_OPTIONS="${NODE_OPTIONS:---enable-source-maps}"

# --- Whitelist of allowed service names ---
# Only the four known GenieACS daemons may be executed. This prevents
# arbitrary command execution if an attacker or misconfiguration passes
# an unexpected value as the service name argument.
case "$SERVICE" in
    genieacs-cwmp|genieacs-nbi|genieacs-fs|genieacs-ui) ;;
    *) echo "Error: Invalid service '$SERVICE'"; exit 1 ;;
esac

# --- Replace the shell process with the actual service ---
# `exec` is used intentionally so the service becomes PID 1 (or the direct
# child of supervisord). This ensures that signals (SIGTERM, SIGINT) sent
# by Docker or supervisord are delivered directly to the Node.js process
# instead of to this wrapper shell, enabling clean and timely shutdowns.
exec /opt/genieacs/node_modules/.bin/$SERVICE