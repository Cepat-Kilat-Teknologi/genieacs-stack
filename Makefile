# Makefile for GenieACS Docker Build and Deployment
.PHONY: help build buildx push up down logs stop restart clean setup scan verify-deps

# Variables
IMAGE_NAME = cepatkilatteknologi/genieacs
VERSION = v1.2.13
TAG = $(VERSION)
LATEST = latest
PLATFORMS = linux/amd64,linux/arm64
COMPOSE_FILE = docker-compose.yml

# Default target
help:
	@echo "GenieACS Docker Management Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  setup       - Create required configuration files"
	@echo "  build       - Build Docker image for current platform"
	@echo "  buildx      - Build multi-platform image using buildx"
	@echo "  push        - Push image to registry"
	@echo "  up          - Start services with docker-compose"
	@echo "  down        - Stop and remove services"
	@echo "  logs        - View service logs"
	@echo "  stop        - Stop services"
	@echo "  restart     - Restart services"
	@echo "  clean       - Clean up resources"
	@echo "  scan        - Scan image for vulnerabilities"
	@echo "  verify-deps - Verify dependency versions"
	@echo ""
	@echo "Variables:"
	@echo "  IMAGE_NAME=$(IMAGE_NAME)"
	@echo "  VERSION=$(VERSION)"
	@echo "  PLATFORMS=$(PLATFORMS)"

# Create required configuration files
setup:
	@echo "Creating configuration files..."
	@mkdir -p config ext
	@echo "/var/log/genieacs/*.{log,yaml} {" > genieacs.logrotate
	@echo "    daily" >> genieacs.logrotate
	@echo "    rotate 30" >> genieacs.logrotate
	@echo "    compress" >> genieacs.logrotate
	@echo "    delaycompress" >> genieacs.logrotate
	@echo "    dateext" >> genieacs.logrotate
	@echo "}" >> genieacs.logrotate
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
	docker-compose -f $(COMPOSE_FILE) up -d

# Stop and remove services
down:
	docker-compose -f $(COMPOSE_FILE) down

# View service logs
logs:
	docker-compose -f $(COMPOSE_FILE) logs -f

# Stop services
stop:
	docker-compose -f $(COMPOSE_FILE) stop

# Restart services
restart:
	docker-compose -f $(COMPOSE_FILE) restart

# Clean up resources
clean:
	docker-compose -f $(COMPOSE_FILE) down -v
	docker image prune -f
	docker builder prune -f
	@echo "Cleanup completed"

# Show running services
ps:
	docker-compose -f $(COMPOSE_FILE) ps

# Show service status
status:
	@echo "=== Service Status ==="
	@docker-compose -f $(COMPOSE_FILE) ps
	@echo ""
	@echo "=== Container Health ==="
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(genieacs|mongo)" || true

# Test the health of the services
test:
	@echo "Testing services health..."
	@sleep 20
	@curl -f http://localhost:3000/ && echo "GenieACS UI health check passed" || echo "GenieACS UI health check failed"
	@docker exec mongo-genieacs mongosh --eval "db.adminCommand('ping')" && echo "MongoDB health check passed" || echo "MongoDB health check failed"

# Build and verify
secure-build: build verify-deps scan