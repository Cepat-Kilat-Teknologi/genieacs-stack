# =============================================================================
# Makefile for GenieACS Stack - Build and Deployment
# =============================================================================
#
# Primary build and management tool for the GenieACS Docker stack.
# Provides targets for building multi-platform images, managing Docker Compose
# services, database backup/restore, user provisioning, and linting.
#
# Quick reference:
#   make help        - Show all available targets
#   make setup       - One-time project initialization
#   make up-d        - Start the full stack in the background
#   make create-user - Provision a GenieACS admin account
#
# =============================================================================

.PHONY: help build buildx buildx-load push up down logs stop restart clean setup scan verify-deps \
        test status ps shell-mongo shell-genieacs backup restore prune create-user fresh \
        lint-docker lint-helm helm-template

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
# IMAGE_NAME: Docker Hub repository path where the image is pushed/pulled.
IMAGE_NAME = cepatkilatteknologi/genieacs
# VERSION: Pinned GenieACS release version used as the primary image tag.
VERSION = v1.2.16
# TAG: Image tag derived from VERSION; override with `make build TAG=custom`.
TAG = $(VERSION)
# LATEST: Convenience tag so `docker pull <image>:latest` always works.
LATEST = latest
# PLATFORMS: Target architectures for multi-platform (buildx) builds.
PLATFORMS = linux/amd64,linux/arm64
# COMPOSE_FILE: Path to the Docker Compose manifest that defines all services.
COMPOSE_FILE = docker-compose.yml
# COMPOSE: Shorthand for invoking Docker Compose with the correct file.
COMPOSE = docker compose -f $(COMPOSE_FILE)

# ---------------------------------------------------------------------------
# Help / Default Target
# ---------------------------------------------------------------------------
# Running `make` with no arguments prints a human-friendly usage summary.
help:
	@echo "GenieACS Stack Management"
	@echo ""
	@echo "Quick Start:"
	@echo "  make setup       - Create config files and directories"
	@echo "  make up-d        - Start services (background, recommended)"
	@echo "  make create-user - Create admin user from .env"
	@echo "  make test        - Test all service endpoints"
	@echo "  make down        - Stop and remove services"
	@echo ""
	@echo "Build:"
	@echo "  make build       - Build Docker image"
	@echo "  make buildx      - Build multi-platform image"
	@echo "  make buildx-push - Build and push to registry"
	@echo ""
	@echo "Service Management:"
	@echo "  make up          - Start services (foreground)"
	@echo "  make logs        - View service logs"
	@echo "  make status      - Show service status and health"
	@echo "  make ps          - Show running containers"
	@echo "  make restart     - Restart services"
	@echo "  make stats       - Show resource usage"
	@echo ""
	@echo "Database:"
	@echo "  make shell-mongo - Access MongoDB shell"
	@echo "  make backup      - Backup MongoDB data"
	@echo "  make restore     - Restore from backup (FILE=path)"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean       - Stop and remove containers/volumes"
	@echo "  make fresh       - Clean and start fresh"
	@echo "  make prune       - Prune unused Docker resources"

# ---------------------------------------------------------------------------
# Project Setup
# ---------------------------------------------------------------------------
# One-time initialization: creates required directories and a .env file from
# the example template. If .env already exists, it scans for well-known
# placeholder strings (e.g., "changeme", "your-super-secret") to warn the
# operator that default secrets have not been replaced yet. This prevents
# accidentally running services with insecure credentials.
setup:
	@echo "Creating directories..."
	@mkdir -p config ext backups
	@if [ ! -f .env ]; then \
		echo "Creating .env from .env.example..."; \
		cp .env.example .env; \
		echo ""; \
		echo "⚠  Please edit .env and set secure values before starting services."; \
		echo "   Generate secrets with: openssl rand -hex 32"; \
	else \
		echo ".env already exists"; \
		if grep -qE 'changeme|change-me|change-this|your-super-secret|YOUR_PASSWORD_HERE' .env 2>/dev/null; then \
			echo ""; \
			echo "⚠  WARNING: .env contains placeholder values!"; \
			echo "   Edit .env and replace all placeholder secrets before running services."; \
			echo "   Generate secrets with: openssl rand -hex 32"; \
		fi; \
	fi
	@echo ""
	@echo "Setup completed!"

# ---------------------------------------------------------------------------
# Build Targets
# ---------------------------------------------------------------------------
# These targets produce the GenieACS Docker image. Choose the right one
# based on whether you need a single-platform local image or a
# multi-architecture image for registry distribution.

# Build a single-platform image using the standard Docker builder.
# Suitable for local development on the host's native architecture.
build:
	docker build --no-cache -t $(IMAGE_NAME):$(TAG) -t $(IMAGE_NAME):$(LATEST) .

# Build for multiple platforms using buildx (amd64 + arm64).
# The resulting manifest is stored in the buildx cache but NOT loaded into
# the local Docker daemon (use buildx-load for that).
buildx:
	docker buildx build --platform $(PLATFORMS) --no-cache \
		-t $(IMAGE_NAME):$(TAG) \
		-t $(IMAGE_NAME):$(LATEST) \
		.

# Build with buildx for the host's architecture only and load the image into
# the local Docker daemon. Useful when you want buildx features (e.g., cache
# mounts) but only need the image locally.
buildx-load:
	docker buildx build --platform linux/$$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
		--load -t $(IMAGE_NAME):$(TAG) -t $(IMAGE_NAME):$(LATEST) .

# Build multi-platform images and push them directly to the registry in one
# step. This is the standard release workflow for publishing new versions.
buildx-push:
	docker buildx build --platform $(PLATFORMS) --no-cache \
		-t $(IMAGE_NAME):$(TAG) \
		-t $(IMAGE_NAME):$(LATEST) \
		--push .

# Push a previously built single-platform image to the registry.
# For multi-platform pushes, prefer buildx-push instead.
push:
	docker push $(IMAGE_NAME):$(TAG)
	docker push $(IMAGE_NAME):$(LATEST)

# ---------------------------------------------------------------------------
# Verification and Security Scanning
# ---------------------------------------------------------------------------

# Verify that critical NPM dependencies are installed at the expected
# versions inside the built image. Helps catch failed or partial installs.
verify-deps:
	@echo "Verifying dependency versions..."
	@docker run --rm $(IMAGE_NAME):$(LATEST) sh -c \
		"cd /opt/genieacs && \
		echo '=== NPM Dependencies ===' && \
		npm ls koa path-to-regexp cross-spawn brace-expansion micromatch && \
		echo '' && \
		echo '=== Binary Check ===' && \
		ls -la bin/ && \
		which genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui"

# Run Docker Scout to identify known CVEs in the image layers.
# Requires Docker Scout CLI plugin (included in Docker Desktop).
scan:
	docker scout quickview $(IMAGE_NAME):$(LATEST)
	docker scout cves $(IMAGE_NAME):$(LATEST)

# ---------------------------------------------------------------------------
# Service Management
# ---------------------------------------------------------------------------
# These targets control the Docker Compose lifecycle. "up" runs in the
# foreground for debugging; "up-d" runs detached for normal operation.

# Start services in the foreground (Ctrl-C to stop). Useful for watching
# logs during development or initial troubleshooting.
up:
	$(COMPOSE) up

# Start services detached (recommended for normal use). Waits a few seconds
# for containers to initialize, then prints their health status.
up-d:
	$(COMPOSE) up -d
	@echo ""
	@echo "Waiting for services to be healthy..."
	@sleep 5
	@$(MAKE) status

# Stop and remove containers and networks. Volumes are preserved so
# database data survives restarts. Use `make clean` to also remove volumes.
down:
	$(COMPOSE) down

# Tail and follow logs from all services. Press Ctrl-C to stop following.
logs:
	$(COMPOSE) logs -f

# Stop services without removing containers. A subsequent `make up` or
# `docker compose start` will resume from the same state.
stop:
	$(COMPOSE) stop

# Restart services
restart:
	$(COMPOSE) restart

# ---------------------------------------------------------------------------
# Cleanup Targets
# ---------------------------------------------------------------------------

# Stop containers, remove them, their networks, AND their volumes.
# WARNING: This destroys all MongoDB data. Back up first with `make backup`.
clean:
	$(COMPOSE) down -v --remove-orphans
	@echo "Cleanup completed"

# Tear down everything (including volumes) and spin up fresh containers.
# Polls the GenieACS container health check for up to 60 seconds so the
# operator knows when the UI is ready.
fresh: clean up-d
	@echo ""
	@echo "Waiting for GenieACS to be healthy..."
	@for i in 1 2 3 4 5 6 7 8 9 10 11 12; do \
		STATUS=$$(docker inspect --format='{{.State.Health.Status}}' genieacs 2>/dev/null || echo "starting"); \
		echo "  GenieACS status: $$STATUS"; \
		if [ "$$STATUS" = "healthy" ]; then break; fi; \
		sleep 5; \
	done
	@echo ""
	@$(MAKE) status

# ---------------------------------------------------------------------------
# Status and Diagnostics
# ---------------------------------------------------------------------------

# List running containers defined by the Compose file.
ps:
	$(COMPOSE) ps

# Show container status and Docker health check results for quick diagnostics.
status:
	@echo "=== Container Status ==="
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" --filter "name=genieacs" --filter "name=mongo"
	@echo ""
	@echo "=== Health Status ==="
	@echo -n "MongoDB:  "
	@docker inspect --format='{{.State.Health.Status}}' mongo-genieacs 2>/dev/null || echo "not running"
	@echo -n "GenieACS: "
	@docker inspect --format='{{.State.Health.Status}}' genieacs 2>/dev/null || echo "not running"

# Smoke-test every GenieACS endpoint by making lightweight HTTP requests.
# CWMP returns 405 (Method Not Allowed) on GET because it expects POST from
# CPE devices -- that is still a healthy response. FS returns 404 when no
# file is requested -- also healthy.
test:
	@echo "=== Testing Services ==="
	@echo ""
	@echo -n "MongoDB: "
	@docker exec mongo-genieacs mongosh --quiet --eval "db.adminCommand('ping').ok" 2>/dev/null && echo "OK" || echo "FAILED"
	@echo -n "GenieACS UI (3000): "
	@curl -sf http://localhost:3000/ > /dev/null && echo "OK" || echo "FAILED"
	@echo -n "GenieACS CWMP (7547): "
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:7547/ | grep -qE "^(200|405)$$" && echo "OK" || echo "FAILED"
	@echo -n "GenieACS NBI (7557): "
	@curl -sf http://localhost:7557/devices > /dev/null && echo "OK" || echo "FAILED"
	@echo -n "GenieACS FS (7567): "
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:7567/ | grep -qE "^(200|404)$$" && echo "OK" || echo "FAILED"

# ---------------------------------------------------------------------------
# Interactive Shells
# ---------------------------------------------------------------------------

# Open an interactive MongoDB shell connected to the genieacs database.
# Useful for inspecting users, devices, presets, etc.
shell-mongo:
	docker exec -it mongo-genieacs mongosh genieacs

# Open a bash shell inside the GenieACS container for debugging.
shell-genieacs:
	docker exec -it genieacs /bin/bash

# ---------------------------------------------------------------------------
# Database Backup and Restore
# ---------------------------------------------------------------------------

# Dump the entire genieacs database as a gzip-compressed archive.
# Backups are timestamped and stored in the local backups/ directory.
backup:
	@echo "Backing up MongoDB data..."
	@mkdir -p backups
	@docker exec mongo-genieacs mongodump --archive --gzip --db=genieacs > backups/backup_$$(date +%Y%m%d_%H%M%S).gz
	@echo "Backup completed: backups/backup_$$(date +%Y%m%d_%H%M%S).gz"

# Restore a database from a backup file. The --drop flag replaces existing
# collections so the database matches the backup exactly.
# Usage: make restore FILE=backups/backup_YYYYMMDD_HHMMSS.gz
restore:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make restore FILE=backups/backup_YYYYMMDD_HHMMSS.gz"; \
		echo ""; \
		echo "Available backups:"; \
		ls -la backups/*.gz 2>/dev/null || echo "  No backups found"; \
	else \
		echo "Restoring from $(FILE)..."; \
		docker exec -i mongo-genieacs mongorestore --archive --gzip --drop < $(FILE); \
		echo "Restore completed"; \
	fi

# Remove containers, locally built images, volumes, and orphan containers
# that belong to THIS project only. Unlike `docker system prune`, this is
# scoped to the Compose project and will not affect other Docker workloads.
prune:
	$(COMPOSE) down --rmi local --volumes --remove-orphans
	@echo "Project resources pruned"

# Composite target: build the image, verify dependencies, then scan for CVEs.
# Use this as a pre-release quality gate.
secure-build: build verify-deps scan

# Show a single snapshot of CPU, memory, and network I/O for the stack
# containers. Omit --no-stream to watch continuously.
stats:
	docker stats mongo-genieacs genieacs --no-stream

# ---------------------------------------------------------------------------
# User Management
# ---------------------------------------------------------------------------

# Provision a GenieACS admin user by calling the helper script, which reads
# credentials from .env (GENIEACS_ADMIN_USERNAME / GENIEACS_ADMIN_PASSWORD)
# and hashes the password using PBKDF2-SHA512 before inserting into MongoDB.
create-user:
	@./scripts/create-user.sh

# ---------------------------------------------------------------------------
# Linting and Validation
# ---------------------------------------------------------------------------

# Lint the Dockerfile using Hadolint for best-practice compliance.
lint-docker:
	@docker run --rm -i hadolint/hadolint < Dockerfile

# Lint all Helm charts in strict mode to catch template and values errors
# before deploying to Kubernetes.
lint-helm:
	@helm lint examples/default/helm/genieacs --strict
	@helm lint examples/nbi-auth/helm/genieacs --strict
	@echo "All Helm charts passed linting"

# Render Helm templates to stdout without installing. Useful for reviewing
# the final Kubernetes manifests that Helm would apply.
helm-template:
	@helm template test examples/default/helm/genieacs
	@helm template test examples/nbi-auth/helm/genieacs