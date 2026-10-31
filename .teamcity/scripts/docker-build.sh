#!/usr/bin/env bash
set -euo pipefail

: "${NEXUS_REGISTRY:?NEXUS_REGISTRY가 필요합니다}"
: "${DOCKER_IMAGE:?DOCKER_IMAGE가 필요합니다}"
: "${BUILD_NUMBER:?BUILD_NUMBER가 필요합니다}"

IMAGE="${NEXUS_REGISTRY}/${DOCKER_IMAGE}"

docker build \
  --platform linux/amd64 \
  --pull \
  --label "org.opencontainers.image.revision=${BUILD_VCS_NUMBER:-unknown}" \
  --tag "${IMAGE}:${BUILD_NUMBER}" \
  --tag "${IMAGE}:latest" \
  app
