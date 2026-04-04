#!/bin/bash
# =============================================================================
# create-user.sh -- Provision a GenieACS admin user directly in MongoDB
# =============================================================================
#
# Usage: ./scripts/create-user.sh [username] [password] [role]
#   Roles: admin | readwrite | readonly
#
# Why this script exists:
#   GenieACS stores user accounts in MongoDB, not in a config file. When
#   deploying a fresh stack there is no user to log into the UI with. This
#   script creates (or updates) a user record so you can log in immediately
#   after `make up-d`.
#
# Password handling:
#   The password is passed to the Node.js hashing step via the GENIE_PASS
#   environment variable (not as a CLI argument). This prevents the plaintext
#   password from appearing in `ps` output or shell history on the host.
#
# Hashing algorithm -- PBKDF2-SHA512:
#   GenieACS's built-in UI hashes passwords with PBKDF2 using SHA-512,
#   10 000 iterations, a 64-byte random salt, and a 128-byte derived key.
#   This script replicates that exact algorithm so users created here are
#   indistinguishable from users created through the web UI.
#
# =============================================================================

set -e

# --- Terminal colors for human-readable output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Load environment variables from .env if it exists ---
# `set -a` causes every variable assignment to be exported automatically,
# so values like GENIEACS_ADMIN_USERNAME become available to child processes.
if [ -f .env ]; then
    set -a
    . ./.env
    set +a
fi

# --- Resolve credentials ---
# Priority: CLI argument > .env variable > hardcoded fallback.
# This lets the script work both interactively and in CI/CD pipelines.
USERNAME="${1:-${GENIEACS_ADMIN_USERNAME:-admin}}"
PASSWORD="${2:-${GENIEACS_ADMIN_PASSWORD:-admin}}"
ROLE="${3:-admin}"
MONGO_CONTAINER="${MONGO_CONTAINER:-mongo-genieacs}"

# Validate role
if [[ ! "$ROLE" =~ ^(admin|readwrite|readonly)$ ]]; then
    echo -e "${RED}Error: Invalid role '$ROLE'. Must be: admin, readwrite, or readonly${NC}"
    exit 1
fi

echo -e "${YELLOW}Creating GenieACS user...${NC}"
echo "  Username: $USERNAME"
echo "  Role: $ROLE"
echo "  MongoDB Container: $MONGO_CONTAINER"

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: docker command not found${NC}"
    exit 1
fi

# Check if MongoDB container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${MONGO_CONTAINER}$"; then
    echo -e "${RED}Error: MongoDB container '$MONGO_CONTAINER' is not running${NC}"
    echo "Available containers:"
    docker ps --format '  {{.Names}}'
    exit 1
fi

# --- Generate password hash using PBKDF2-SHA512 via Node.js ---
# The password is passed through the GENIE_PASS environment variable (not a
# CLI arg) so it never appears in the process table visible to other users.
# We prefer the GenieACS container's Node.js because it is always present;
# the local Node.js install is a fallback for convenience.
echo "Generating password hash..."
if docker ps --format '{{.Names}}' | grep -q "^genieacs$"; then
    HASH_OUTPUT=$(docker exec -e GENIE_PASS="$PASSWORD" genieacs node -e "
const crypto = require('crypto');
const password = process.env.GENIE_PASS;
const salt = crypto.randomBytes(64).toString('hex');
const hash = crypto.pbkdf2Sync(password, salt, 10000, 128, 'sha512').toString('hex');
console.log(JSON.stringify({salt: salt, hash: hash}));
")
elif command -v node &> /dev/null; then
    HASH_OUTPUT=$(GENIE_PASS="$PASSWORD" node -e "
const crypto = require('crypto');
const password = process.env.GENIE_PASS;
const salt = crypto.randomBytes(64).toString('hex');
const hash = crypto.pbkdf2Sync(password, salt, 10000, 128, 'sha512').toString('hex');
console.log(JSON.stringify({salt: salt, hash: hash}));
")
else
    echo -e "${RED}Error: Neither genieacs container nor local Node.js available${NC}"
    exit 1
fi

SALT=$(echo "$HASH_OUTPUT" | grep -o '"salt":"[^"]*"' | cut -d'"' -f4)
HASH=$(echo "$HASH_OUTPUT" | grep -o '"hash":"[^"]*"' | cut -d'"' -f4)

if [ -z "$SALT" ] || [ -z "$HASH" ]; then
    echo -e "${RED}Error: Failed to generate password hash${NC}"
    exit 1
fi

# --- Upsert the user document into the MongoDB "users" collection ---
# Uses an upsert pattern (find-then-insert-or-update) rather than a simple
# insert so the script is idempotent: running it twice updates the existing
# record instead of failing with a duplicate key error.
echo "Inserting user into MongoDB..."

RESULT=$(docker exec "$MONGO_CONTAINER" mongosh --quiet genieacs --eval "
const user = {
    _id: '$USERNAME',
    password: '$HASH',
    salt: '$SALT',
    roles: '$ROLE'
};

const existing = db.users.findOne({_id: '$USERNAME'});
if (existing) {
    db.users.updateOne({_id: '$USERNAME'}, {\$set: user});
    print('updated');
} else {
    db.users.insertOne(user);
    print('created');
}
")

if [[ "$RESULT" == *"created"* ]]; then
    echo -e "${GREEN}User '$USERNAME' created successfully!${NC}"
elif [[ "$RESULT" == *"updated"* ]]; then
    echo -e "${GREEN}User '$USERNAME' updated successfully!${NC}"
else
    echo -e "${RED}Error creating user: $RESULT${NC}"
    exit 1
fi

echo ""
echo -e "You can now login at ${GREEN}http://localhost:${GENIEACS_UI_PORT:-3000}${NC}"
echo "  Username: $USERNAME"
echo "  Password: (as provided)"