#!/bin/bash
# Script to create GenieACS user via NBI API
# Usage: ./scripts/create-user.sh [username] [password] [role]
# Roles: admin, readwrite, readonly

set -e

# Load environment variables from .env if exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Default values
USERNAME="${1:-${GENIEACS_ADMIN_USERNAME:-admin}}"
PASSWORD="${2:-${GENIEACS_ADMIN_PASSWORD:-admin}}"
ROLE="${3:-admin}"
NBI_PORT="${GENIEACS_NBI_PORT:-7557}"
NBI_HOST="${GENIEACS_NBI_HOST:-localhost}"

echo "Creating GenieACS user..."
echo "  Username: $USERNAME"
echo "  Role: $ROLE"
echo "  NBI Endpoint: http://$NBI_HOST:$NBI_PORT"

# Create password hash using Node.js (same method GenieACS uses)
SALT=$(openssl rand -hex 16)
HASH=$(echo -n "${PASSWORD}${SALT}" | openssl dgst -sha256 -hex | awk '{print $2}')

# Create user via NBI API
curl -s -X PUT "http://$NBI_HOST:$NBI_PORT/users/${USERNAME}" \
    -H "Content-Type: application/json" \
    -d "{
        \"_id\": \"${USERNAME}\",
        \"password\": \"${HASH}\",
        \"salt\": \"${SALT}\",
        \"roles\": \"${ROLE}\"
    }"

echo ""
echo "User '$USERNAME' created successfully!"
echo "You can now login at http://localhost:${GENIEACS_UI_PORT:-3000}"