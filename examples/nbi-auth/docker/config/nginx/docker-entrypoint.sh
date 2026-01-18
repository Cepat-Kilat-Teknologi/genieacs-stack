#!/bin/sh
# Nginx entrypoint - generates config from template

set -e

CONFIG_TEMPLATE="/etc/nginx/nbi-proxy.conf.template"
CONFIG_OUTPUT="/etc/nginx/nginx.conf"

if [ -z "$GENIEACS_NBI_API_KEY" ]; then
    echo "Error: GENIEACS_NBI_API_KEY is required"
    exit 1
fi

echo "Generating nginx config..."
envsubst '${GENIEACS_NBI_API_KEY}' < "$CONFIG_TEMPLATE" > "$CONFIG_OUTPUT"

echo "Starting nginx..."
exec nginx -g "daemon off;"