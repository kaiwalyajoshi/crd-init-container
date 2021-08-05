MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR := $(dir $(MAKEFILE_PATH))

CRD_INIT_CONTAINER_GITTAG_PREFIX := "crd-init-container"
CRD_INIT_CONTAINER_VERSION := $(shell git tag --points-at HEAD --sort -version:creatordate \
	| grep -e "$(CRD_INIT_CONTAINER_GITTAG_PREFIX)" \
	| sed -e "s|$(CRD_INIT_CONTAINER_GITTAG_PREFIX)/||" \
	| head -n 1)

ifeq ($(CRD_INIT_CONTAINER_VERSION),)
	CRD_INIT_CONTAINER_VERSION := $(shell git describe --abbrev=0 --tags \
	| grep -e "$(CRD_INIT_CONTAINER_GITTAG_PREFIX)" \
	| sed -e "s|$(CRD_INIT_CONTAINER_GITTAG_PREFIX)/||" \
	| head -n 1)-SNAPSHOT-$(shell git rev-parse --short HEAD)
endif

CRD_INIT_CONTAINER_IMAGE := kaiwalyarjoshi/crd-init-container
CRD_INIT_CONTAINER_TAG := $(CRD_INIT_CONTAINER_GITTAG_PREFIX)$(CRD_INIT_CONTAINER_VERSION)

.PHONY: crd-init-container.build
crd-init-container.build: ## build the crd-init-container go binary
crd-init-container.build:
	$(call print-target)
	cd $(MAKEFILE_DIR) && CGO_ENABLED=0 go build -tags netgo -ldflags '-w -extldflags "-static"' .

.PHONY: crd-init-container.build-image
crd-init-container.build-image: ## build the crd-init-container image
crd-init-container.build-image: crd-init-container.build
	$(call print-target)
	cd $(MAKEFILE_DIR) && docker build -t $(CRD_INIT_CONTAINER_IMAGE):$(CRD_INIT_CONTAINER_TAG) $(MAKEFILE_DIR)

.PHONY: crd-init-container.push-image
crd-init-container.push-image: ## push the crd-init-container image
crd-init-container.push-image: crd-init-container.build-image
	$(call print-target)
	$(call docker_push, $(CRD_INIT_CONTAINER_IMAGE):$(CRD_INIT_CONTAINER_TAG))

.PHONY: help
help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[.0-9A-Za-z_-]+:.*?##/ { printf "  \033[36m%-45s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
