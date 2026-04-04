#!/bin/bash
# =============================================================================
# create-user.sh -- Provision a GenieACS user and bootstrap a fresh install
# =============================================================================
#
# Usage: ./scripts/create-user.sh [username] [password] [role]
#   Roles: admin | readwrite | readonly
#
# What this script does:
#   1. Creates (or updates) a user in the GenieACS MongoDB "users" collection
#   2. If the role is "admin", ensures permissions exist for the admin role
#   3. On a fresh install (no UI config), triggers GenieACS init to create
#      default presets, provisions, filters, and overview layout
#   4. Invalidates the GenieACS internal cache so changes take effect immediately
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
GENIEACS_CONTAINER="${GENIEACS_CONTAINER:-genieacs}"

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

# --- Build MongoDB connection URI ---
MONGO_USER="${MONGO_INITDB_ROOT_USERNAME:-admin}"
MONGO_PASS="${MONGO_INITDB_ROOT_PASSWORD:-}"
MONGO_URI="mongodb://${MONGO_USER}:${MONGO_PASS}@localhost:27017/genieacs?authSource=admin"

# --- Generate password hash using PBKDF2-SHA512 via Node.js ---
# The password is passed through the GENIE_PASS environment variable (not a
# CLI arg) so it never appears in the process table visible to other users.
# We prefer the GenieACS container's Node.js because it is always present;
# the local Node.js install is a fallback for convenience.
echo "Generating password hash..."
if docker ps --format '{{.Names}}' | grep -q "^${GENIEACS_CONTAINER}$"; then
    HASH_OUTPUT=$(docker exec -e GENIE_PASS="$PASSWORD" "$GENIEACS_CONTAINER" node -e "
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

RESULT=$(docker exec "$MONGO_CONTAINER" mongosh --quiet "$MONGO_URI" --eval "
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

if [[ "$RESULT" != *"created"* ]] && [[ "$RESULT" != *"updated"* ]]; then
    echo -e "${RED}Error creating user: $RESULT${NC}"
    exit 1
fi

if [[ "$RESULT" == *"created"* ]]; then
    echo -e "${GREEN}User '$USERNAME' created successfully!${NC}"
else
    echo -e "${GREEN}User '$USERNAME' updated successfully!${NC}"
fi

# --- Setup admin permissions if role is admin ---
# GenieACS requires permission entries in the "permissions" collection for each
# role. Without these, a logged-in user sees "You are not authorized to view
# this page". This is a chicken-and-egg problem on fresh installs: the /init
# endpoint needs permissions, but permissions don't exist yet.
#
# We only insert permissions for the "admin" role. Other roles (readwrite,
# readonly) should be configured manually via the Admin > Permissions UI.
if [[ "$ROLE" == "admin" ]]; then
    PERM_COUNT=$(docker exec "$MONGO_CONTAINER" mongosh --quiet "$MONGO_URI" --eval \
        "db.permissions.countDocuments({role: 'admin'})" 2>/dev/null)

    if [[ "$PERM_COUNT" -eq 0 ]] 2>/dev/null; then
        echo "Setting up admin permissions..."
        docker exec "$MONGO_CONTAINER" mongosh --quiet "$MONGO_URI" --eval '
const resources = [
    "devices", "presets", "provisions", "virtualParameters",
    "files", "faults", "tasks", "config", "users", "permissions"
];
for (const resource of resources) {
    for (const access of [1, 2, 3]) {
        db.permissions.replaceOne(
            { _id: `admin:${resource}:${access}` },
            { _id: `admin:${resource}:${access}`, role: "admin", resource, access, filter: "true", validate: "true" },
            { upsert: true }
        );
    }
}
print("done");
' > /dev/null 2>&1
        echo -e "${GREEN}Admin permissions configured (30 entries)${NC}"
    fi
fi

# --- Bootstrap fresh install: trigger GenieACS UI init ---
# On a fresh install the config collection is empty, meaning no presets,
# provisions, filters, or overview layout exist. The GenieACS UI has a
# POST /init endpoint that creates these defaults. We call it here so the
# user gets a fully working dashboard on first login.
CONFIG_COUNT=$(docker exec "$MONGO_CONTAINER" mongosh --quiet "$MONGO_URI" --eval \
    "db.config.countDocuments()" 2>/dev/null)

if [[ "$CONFIG_COUNT" -eq 0 ]] 2>/dev/null; then
    echo "Fresh install detected, bootstrapping default config..."

    # GenieACS cache must see the new permissions before /init will work
    docker exec "$MONGO_CONTAINER" mongosh --quiet "$MONGO_URI" --eval \
        'db.cache.deleteOne({_id: "ui-local-cache-hash"})' > /dev/null 2>&1
    sleep 3

    UI_PORT="${GENIEACS_UI_PORT:-3000}"

    # Login to get JWT token
    TOKEN=$(curl -sf "http://localhost:${UI_PORT}/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}" 2>/dev/null | tr -d '"')

    if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
        # POST /init creates default presets (bootstrap, default, inform),
        # provisions, overview layout, device page columns, and index page filters.
        # "users" is set to false because we already created the user above;
        # passing true would overwrite our user with GenieACS defaults (password "admin").
        INIT_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${UI_PORT}/init" \
            -H "Content-Type: application/json" \
            -H "Cookie: genieacs-ui-jwt=$TOKEN" \
            -d '{"users":false,"filters":true,"device":true,"index":true,"overview":true,"presets":true}' 2>/dev/null)

        if [ "$INIT_CODE" = "200" ]; then
            echo -e "${GREEN}Default config bootstrapped (presets, provisions, overview)${NC}"
        else
            echo -e "${YELLOW}Warning: Init returned HTTP $INIT_CODE (config may need manual setup)${NC}"
        fi
    else
        echo -e "${YELLOW}Warning: Could not obtain login token for init (setup manually via UI)${NC}"
    fi
fi

# --- Invalidate GenieACS cache ---
# GenieACS caches user data in an internal snapshot (refreshed every ~5s).
# Deleting the cache key forces an immediate reload on the next request,
# so the new user can log in without waiting for the refresh cycle.
docker exec "$MONGO_CONTAINER" mongosh --quiet "$MONGO_URI" --eval \
    'db.cache.deleteOne({_id: "ui-local-cache-hash"})' > /dev/null 2>&1

echo ""
echo -e "You can now login at ${GREEN}http://localhost:${GENIEACS_UI_PORT:-3000}${NC}"
echo "  Username: $USERNAME"
echo "  Password: (as provided)"
