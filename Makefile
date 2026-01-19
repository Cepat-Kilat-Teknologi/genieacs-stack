# Makefile for GenieACS Stack - Build and Deployment
.PHONY: help build buildx push up down logs stop restart clean setup scan verify-deps \
        test status ps shell-mongo shell-genieacs backup restore prune create-user fresh

# Variables
IMAGE_NAME = cepatkilatteknologi/genieacs
VERSION = v1.2.13
TAG = $(VERSION)
LATEST = latest
PLATFORMS = linux/amd64,linux/arm64
COMPOSE_FILE = docker-compose.yml
COMPOSE = docker compose -f $(COMPOSE_FILE)

# Default target
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

# Create required configuration files
setup:
	@echo "Creating directories..."
	@mkdir -p config ext backups
	@if [ ! -f .env ]; then \
		echo "Creating .env from .env.example..."; \
		cp .env.example .env; \
		echo "Please edit .env and set GENIEACS_UI_JWT_SECRET"; \
	fi
	@echo "Setup completed!"

# Build for current platform
build:
	docker build --no-cache -t $(IMAGE_NAME):$(TAG) -t $(IMAGE_NAME):$(LATEST) .

# Build for multiple platforms using buildx
buildx:
	docker buildx build --platform $(PLATFORMS) --no-cache \
		-t $(IMAGE_NAME):$(TAG) \
		-t $(IMAGE_NAME):$(LATEST) \
		.

# Build and push for multiple platforms
buildx-push:
	docker buildx build --platform $(PLATFORMS) --no-cache \
		-t $(IMAGE_NAME):$(TAG) \
		-t $(IMAGE_NAME):$(LATEST) \
		--push .

# Push to registry
push:
	docker push $(IMAGE_NAME):$(TAG)
	docker push $(IMAGE_NAME):$(LATEST)

# Verify dependencies are updated
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

# Scan image for vulnerabilities
scan:
	docker scout quickview $(IMAGE_NAME):$(LATEST)
	docker scout cves $(IMAGE_NAME):$(LATEST)

# Start services (foreground)
up:
	$(COMPOSE) up

# Start services (background)
up-d:
	$(COMPOSE) up -d
	@echo ""
	@echo "Waiting for services to be healthy..."
	@sleep 5
	@$(MAKE) status

# Stop and remove services
down:
	$(COMPOSE) down

# View service logs
logs:
	$(COMPOSE) logs -f

# Stop services
stop:
	$(COMPOSE) stop

# Restart services
restart:
	$(COMPOSE) restart

# Clean up resources
clean:
	$(COMPOSE) down -v --remove-orphans
	@echo "Cleanup completed"

# Fresh start - clean and start
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

# Show running services
ps:
	$(COMPOSE) ps

# Show service status
status:
	@echo "=== Container Status ==="
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" --filter "name=genieacs" --filter "name=mongo"
	@echo ""
	@echo "=== Health Status ==="
	@echo -n "MongoDB:  "
	@docker inspect --format='{{.State.Health.Status}}' mongo-genieacs 2>/dev/null || echo "not running"
	@echo -n "GenieACS: "
	@docker inspect --format='{{.State.Health.Status}}' genieacs 2>/dev/null || echo "not running"

# Test the health of the services
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

# Access MongoDB container shell
shell-mongo:
	docker exec -it mongo-genieacs mongosh genieacs

# Access GenieACS container shell
shell-genieacs:
	docker exec -it genieacs /bin/bash

# Backup MongoDB data
backup:
	@echo "Backing up MongoDB data..."
	@mkdir -p backups
	@docker exec mongo-genieacs mongodump --archive --gzip --db=genieacs > backups/backup_$$(date +%Y%m%d_%H%M%S).gz
	@echo "Backup completed: backups/backup_$$(date +%Y%m%d_%H%M%S).gz"

# Restore MongoDB data from backup
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

# Prune unused Docker resources
prune:
	docker system prune -f
	docker volume prune -f

# Build and verify
secure-build: build verify-deps scan

# Show Docker resource usage
stats:
	docker stats mongo-genieacs genieacs --no-stream

# Create GenieACS admin user from .env credentials
create-user:
	@./scripts/create-user.sh