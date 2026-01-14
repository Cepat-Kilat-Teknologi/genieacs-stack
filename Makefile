# Makefile for GenieACS Docker Build and Deployment
.PHONY: help build buildx push up down logs stop restart clean setup scan verify-deps \
        test status ps shell-mongo shell-genieacs backup restore prune create-user

# Variables
IMAGE_NAME = cepatkilatteknologi/genieacs
VERSION = v1.2.13
TAG = $(VERSION)
LATEST = latest
PLATFORMS = linux/amd64,linux/arm64
COMPOSE_FILE = docker-compose.yml
COMPOSE_PROJECT_NAME = genieacs

# Default target
help:
	@echo "GenieACS Docker Management Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  setup         - Create required configuration files"
	@echo "  build         - Build Docker image for current platform"
	@echo "  buildx        - Build multi-platform image using buildx"
	@echo "  buildx-push   - Build and push multi-platform image"
	@echo "  push          - Push image to registry"
	@echo "  up            - Start services with docker-compose"
	@echo "  down          - Stop and remove services"
	@echo "  logs          - View service logs"
	@echo "  stop          - Stop services"
	@echo "  restart       - Restart services"
	@echo "  clean         - Clean up resources"
	@echo "  scan          - Scan image for vulnerabilities"
	@echo "  verify-deps   - Verify dependency versions"
	@echo "  test          - Test service health"
	@echo "  status        - Show service status"
	@echo "  ps            - Show running services"
	@echo "  shell-mongo   - Access MongoDB container shell"
	@echo "  shell-genieacs - Access GenieACS container shell"
	@echo "  backup        - Backup MongoDB data"
	@echo "  restore       - Restore MongoDB data from backup"
	@echo "  prune         - Prune unused Docker resources"
	@echo "  secure-build  - Build and verify image security"
	@echo "  create-user   - Create admin user from .env credentials"
	@echo ""
	@echo "Variables:"
	@echo "  IMAGE_NAME=$(IMAGE_NAME)"
	@echo "  VERSION=$(VERSION)"
	@echo "  PLATFORMS=$(PLATFORMS)"
	@echo "  COMPOSE_PROJECT_NAME=$(COMPOSE_PROJECT_NAME)"

# Create required configuration files
setup:
	@echo "Creating configuration files..."
	@mkdir -p config ext backups
	@echo "/var/log/genieacs/*.{log,yaml} {" > config/genieacs.logrotate
	@echo "    daily" >> config/genieacs.logrotate
	@echo "    rotate 30" >> config/genieacs.logrotate
	@echo "    compress" >> config/genieacs.logrotate
	@echo "    delaycompress" >> config/genieacs.logrotate
	@echo "    dateext" >> config/genieacs.logrotate
	@echo "    missingok" >> config/genieacs.logrotate
	@echo "    notifempty" >> config/genieacs.logrotate
	@echo "    copytruncate" >> config/genieacs.logrotate
	@echo "}" >> config/genieacs.logrotate
	@echo "Configuration files created successfully!"

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

# Start services
up:
	docker-compose -f $(COMPOSE_FILE) -p $(COMPOSE_PROJECT_NAME) up -d

# Stop and remove services
down:
	docker-compose -f $(COMPOSE_FILE) -p $(COMPOSE_PROJECT_NAME) down

# View service logs
logs:
	docker-compose -f $(COMPOSE_FILE) -p $(COMPOSE_PROJECT_NAME) logs -f

# Stop services
stop:
	docker-compose -f $(COMPOSE_FILE) -p $(COMPOSE_PROJECT_NAME) stop

# Restart services
restart:
	docker-compose -f $(COMPOSE_FILE) -p $(COMPOSE_PROJECT_NAME) restart

# Clean up resources
clean:
	docker-compose -f $(COMPOSE_FILE) -p $(COMPOSE_PROJECT_NAME) down -v --rmi local
	docker image prune -f
	docker builder prune -f
	@echo "Cleanup completed"

# Show running services
ps:
	docker-compose -f $(COMPOSE_FILE) -p $(COMPOSE_PROJECT_NAME) ps

# Show service status
status:
	@echo "=== Service Status ==="
	@docker-compose -f $(COMPOSE_FILE) -p $(COMPOSE_PROJECT_NAME) ps
	@echo ""
	@echo "=== Container Health ==="
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(genieacs|mongo)" || true
	@echo ""
	@echo "=== Health Checks ==="
	@echo -n "MongoDB: "
	@docker inspect --format='{{.State.Health.Status}}' mongo-genieacs 2>/dev/null || echo "Not available"
	@echo -n "GenieACS: "
	@docker inspect --format='{{.State.Health.Status}}' genieacs 2>/dev/null || echo "Not available"

# Test the health of the services
test:
	@echo "Testing services health..."
	@sleep 10
	@echo "Testing MongoDB..."
	@docker exec mongo-genieacs mongosh --eval "db.adminCommand('ping')" && echo "MongoDB health check passed" || echo "MongoDB health check failed"
	@echo "Testing GenieACS UI..."
	@curl -f http://localhost:3000/ && echo "GenieACS UI health check passed" || echo "GenieACS UI health check failed"
	@echo "Testing GenieACS CWMP..."
	@curl -f http://localhost:7547/ && echo "GenieACS CWMP health check passed" || echo "GenieACS CWMP health check failed"

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
	@echo "Backup completed. File saved in backups/ directory"

# Restore MongoDB data from backup
restore:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make restore FILE=backups/backup_YYYYMMDD_HHMMSS.gz"; \
		echo "Available backups:"; \
		ls -la backups/*.gz 2>/dev/null || echo "No backups found"; \
	else \
		echo "Restoring from $(FILE)..."; \
		docker exec -i mongo-genieacs mongorestore --archive --gzip --drop < $(FILE); \
		echo "Restore completed"; \
	fi

# Prune unused Docker resources
prune:
	docker system prune -f
	docker volume prune -f
	docker network prune -f

# Build and verify
secure-build: build verify-deps scan

# Show Docker resource usage
stats:
	docker stats mongo-genieacs genieacs

# Show container resource limits
resources:
	@echo "=== Container Resource Limits ==="
	@docker inspect mongo-genieacs genieacs --format '{{.Name}} - Memory: {{.HostConfig.Memory}} CPU: {{.HostConfig.NanoCpus}}' | sed 's/\/\///g'

# Create GenieACS admin user from .env credentials
create-user:
	@./scripts/create-user.sh