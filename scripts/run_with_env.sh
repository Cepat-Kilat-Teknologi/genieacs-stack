#!/bin/bash
# run_with_env.sh - Helper script to run GenieACS services
# Usage: run_with_env.sh <service-name>
# Services: genieacs-cwmp, genieacs-nbi, genieacs-fs, genieacs-ui

set -e

SERVICE="$1"

if [ -z "$SERVICE" ]; then
    echo "Usage: $0 <service-name>"
    echo "Services: genieacs-cwmp, genieacs-nbi, genieacs-fs, genieacs-ui"
    exit 1
fi

# Set paths
export PATH="/usr/local/bin:/opt/genieacs/node_modules/.bin:$PATH"

# Set default Node options for better debugging
export NODE_OPTIONS="${NODE_OPTIONS:---enable-source-maps}"

# Execute the service from node_modules/.bin
exec /opt/genieacs/node_modules/.bin/$SERVICE