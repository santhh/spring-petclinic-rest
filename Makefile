SHELL := /bin/bash
IMAGE_NAMESPACE := docker.mdl.cloud
DOCKER_SERVER := docker.mdl.cloud

# Assign circle usernamename, reponame, sha1 name from git when not running on Circle
CIRCLE_PROJECT_USERNAME ?= $(shell git config --get remote.origin.url | \
 																	 awk -F'[/:]' '{print $$(NF-1)}')
CIRCLE_PROJECT_REPONAME ?= $(shell git config --get remote.origin.url | \
 																	 awk -F'/' '{print $$(NF)}' | sed 's/\.git//')
CIRCLE_SHA1 ?= $(shell git rev-parse HEAD)
SHORT_SHA=$(shell git rev-parse --short HEAD)

# lowercase the image owner and repo name and replace `-`
IMAGE_OWNER := $(shell tr '[:upper:]' '[:lower:]' <<< $(CIRCLE_PROJECT_USERNAME) | \
  tr '-' '_')
# exclude the prefix `docker-` from the image repo name
IMAGE_REPO := $(shell tr '[:upper:]' '[:lower:]' <<< $(CIRCLE_PROJECT_REPONAME) | \
  sed s/^docker[-_]//)
# create an ENV var value with just uppercase and _ chars
IMAGE_VAR := $(shell tr '[:lower:]' '[:upper:]' <<< $(IMAGE_REPO) | \
  tr "[:punct:]" "_")
IMAGE_VERSION := $(shell cat VERSION)
IMAGE_TAG := $(IMAGE_NAMESPACE)/$(IMAGE_OWNER)/$(IMAGE_REPO):$(IMAGE_VERSION)
IMAGE_TAG_VERSION := $(IMAGE_TAG)-$(SHORT_SHA)
IMAGE_LATEST := $(IMAGE_NAMESPACE)/$(IMAGE_OWNER)/$(IMAGE_REPO):latest

IMAGE_BASE := $(IMAGE_NAMESPACE)/$(IMAGE_OWNER)/$(IMAGE_REPO)
IMAGE_TAG_MIGRATE_FULL := $(IMAGE_BASE):$(IMAGE_VERSION)-$(SHORT_SHA)-migrate 
IMAGE_TAG_MIGRATE_VANITY := $(IMAGE_BASE):$(IMAGE_VERSION)-migrate
IMAGE_TAG_MIGRATE_LATEST := $(IMAGE_BASE):latest-migrate

.PHONY: build test push

build:
	# <- Build war file on prod mode ->
	./mvnw clean package
	@docker login --email="$(DOCKER_EMAIL)" --username="$(DOCKER_USER)" --password="$(DOCKER_PASS)" $(DOCKER_SERVER)
	cp Dockerfile Dockerfile.tmp
	echo -e '\nENV "$(IMAGE_VAR)_CONTAINER_VERSION"="$(IMAGE_VERSION)"' >> Dockerfile.tmp
	echo 'LABEL "image.tag"="$(IMAGE_TAG)" \
		"image.commit"="$(CIRCLE_SHA1)" \
		"image.build"="$(CIRCLE_SLUG)/$(CIRCLE_BUILD_NUM)"' >> Dockerfile.tmp
	docker build -t $(IMAGE_TAG) -f Dockerfile.tmp .
	docker tag $(IMAGE_TAG) $(IMAGE_TAG_VERSION)
	docker tag $(IMAGE_TAG) $(IMAGE_LATEST)
	rm Dockerfile.tmp
	docker build -t $(IMAGE_TAG_MIGRATE_FULL) -f ./migrations/Dockerfile ./migrations/
	docker tag $(IMAGE_TAG_MIGRATE_FULL) $(IMAGE_TAG_MIGRATE_VANITY)
	docker tag $(IMAGE_TAG_MIGRATE_FULL) $(IMAGE_TAG_MIGRATE_LATEST)
	
test:
	echo 'TODO: Execute Maven test.'
	# mvn clean test

push:
	docker push $(IMAGE_TAG_MIGRATE_FULL)
	docker push $(IMAGE_TAG_MIGRATE_VANITY)
	docker push $(IMAGE_TAG_MIGRATE_LATEST)
	docker push $(IMAGE_TAG)
	docker push $(IMAGE_TAG_VERSION)
	docker push $(IMAGE_LATEST)
	git tag -f "v$(IMAGE_VERSION)"
	git push origin -f "v$(IMAGE_VERSION)"
	echo "Adding VERSION artifact"
	echo $(IMAGE_VERSION)-$(SHORT_SHA) > $(CIRCLE_ARTIFACTS)/VERSION
	