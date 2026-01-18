#!/bin/bash
# Script to create GenieACS user via MongoDB
# Usage: ./scripts/create-user.sh [username] [password] [role]
# Roles: admin, readwrite, readonly
#
# This script uses PBKDF2-SHA512 hashing (same as GenieACS UI)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables from .env if exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs 2>/dev/null) || true
fi

# Default values
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

# Generate password hash using Node.js in genieacs container (PBKDF2-SHA512)
echo "Generating password hash..."

# Try to use genieacs container first, fallback to local node
if docker ps --format '{{.Names}}' | grep -q "^genieacs$"; then
    HASH_OUTPUT=$(docker exec genieacs node -e "
const crypto = require('crypto');
const password = process.argv[1];
const salt = crypto.randomBytes(64).toString('hex');
const hash = crypto.pbkdf2Sync(password, salt, 10000, 128, 'sha512').toString('hex');
console.log(JSON.stringify({salt: salt, hash: hash}));
" "$PASSWORD")
elif command -v node &> /dev/null; then
    HASH_OUTPUT=$(node -e "
const crypto = require('crypto');
const password = process.argv[1];
const salt = crypto.randomBytes(64).toString('hex');
const hash = crypto.pbkdf2Sync(password, salt, 10000, 128, 'sha512').toString('hex');
console.log(JSON.stringify({salt: salt, hash: hash}));
" "$PASSWORD")
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

# Create or update user in MongoDB
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