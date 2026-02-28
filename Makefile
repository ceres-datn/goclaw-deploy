GOCLAW_DIR ?= ../goclaw
IMAGE      ?= itsddvn/goclaw
VERSION    ?= $(shell cd $(GOCLAW_DIR) && git describe --tags --always 2>/dev/null || echo dev)
PLATFORMS  ?= linux/amd64,linux/arm64

.PHONY: build push all version clean

# Build multi-arch image and load to local Docker
build:
	docker buildx build \
		--build-context deploy=. \
		--build-arg VERSION=$(VERSION) \
		--platform $(PLATFORMS) \
		-f Dockerfile \
		-t $(IMAGE):$(VERSION) \
		-t $(IMAGE):latest \
		$(GOCLAW_DIR)

# Build and push to DockerHub
push:
	docker buildx build \
		--build-context deploy=. \
		--build-arg VERSION=$(VERSION) \
		--platform $(PLATFORMS) \
		-f Dockerfile \
		-t $(IMAGE):$(VERSION) \
		-t $(IMAGE):latest \
		--push \
		$(GOCLAW_DIR)

# Build + push
all: push

# Show version
version:
	@echo $(VERSION)

# Remove local images
clean:
	docker rmi $(IMAGE):$(VERSION) $(IMAGE):latest 2>/dev/null || true
