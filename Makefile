# QuantDinger Docker build and run
# Usage: make build | up | down | logs | ps | push
#
# Push to Aliyun ACR:
#   make push REGISTRY=registry.cn-hangzhou.aliyuncs.com/your-namespace TAG=1.0.0
# Then on target machine: docker pull <REGISTRY>/quantdinger-backend:<TAG> etc.

REGISTRY ?= registry.cn-hangzhou.aliyuncs.com
NAMESPACE ?= quantdinger
TAG ?= latest
IMAGE_BACKEND = $(REGISTRY)/$(NAMESPACE)/quantdinger-backend
IMAGE_FRONTEND = $(REGISTRY)/$(NAMESPACE)/quantdinger-frontend

.PHONY: build up down logs ps build-backend build-frontend build-single push push-backend push-frontend push-single

# Build all images (backend + frontend)
build:
	docker-compose build

# Build and start all services in background
up:
	docker-compose up -d --build

# Stop all services
down:
	docker-compose down

# Stop and remove volumes (WARNING: deletes database)
down-v:
	docker-compose down -v

# Follow logs (all services)
logs:
	docker-compose logs -f

# Show running containers
ps:
	docker-compose ps

# Build only backend image
build-backend:
	docker build -t quantdinger-backend:latest ./backend_api_python

# Build only frontend image
build-frontend:
	docker build -t quantdinger-frontend:latest ./quantdinger_vue

# Single image from root Dockerfile (for Aliyun ACR: one image = backend + frontend)
build-single:
	docker build -t quantdinger:latest -f Dockerfile .

# Build, tag and push both images to registry (set REGISTRY, NAMESPACE, TAG)
push: build
	$(MAKE) push-backend push-frontend

push-backend:
	docker tag quantdinger-backend:latest $(IMAGE_BACKEND):$(TAG)
	docker push $(IMAGE_BACKEND):$(TAG)

push-frontend:
	docker tag quantdinger-frontend:latest $(IMAGE_FRONTEND):$(TAG)
	docker push $(IMAGE_FRONTEND):$(TAG)

# Push single root image to ACR (after: make build-single)
push-single:
	docker tag quantdinger:latest $(REGISTRY)/$(NAMESPACE)/quantdinger:$(TAG)
	docker push $(REGISTRY)/$(NAMESPACE)/quantdinger:$(TAG)
