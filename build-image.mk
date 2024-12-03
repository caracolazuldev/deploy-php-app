
default: app

rebuild: system app

SYS_BASE_IMAGE ?= php:cli-bookworm
SYS_IMAGE_TAG ?= deploy-php-app/system

system:
	docker build --no-cache \
	--build-arg BASE_IMAGE=${SYS_BASE_IMAGE} \
	--tag ${SYS_IMAGE_TAG} \
	--file docker/system.dockerfile \
	docker

BASE_IMAGE ?= ${SYS_IMAGE_TAG}
IMAGE_TAG ?= caracolazul/deploy-php-app:latest

app:
	docker build --no-cache \
	--build-arg BASE_IMAGE=${BASE_IMAGE} \
	--tag ${IMAGE_TAG} \
	--file docker/Dockerfile \
	.

