#!/usr/bin/env bash
set -euo pipefail

: "${NEXUS_REGISTRY:?NEXUS_REGISTRY가 필요합니다}"
: "${NEXUS_USERNAME:?NEXUS_USERNAME가 필요합니다}"
: "${NEXUS_PASSWORD:?NEXUS_PASSWORD가 필요합니다}"
: "${DOCKER_IMAGE:?DOCKER_IMAGE가 필요합니다}"
: "${BUILD_NUMBER:?BUILD_NUMBER가 필요합니다}"

IMAGE="${NEXUS_REGISTRY}/${DOCKER_IMAGE}"

cleanup() {
  docker logout "${NEXUS_REGISTRY}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

printf '%s' "${NEXUS_PASSWORD}" | \
  docker login "${NEXUS_REGISTRY}" \
    --username "${NEXUS_USERNAME}" \
    --password-stdin

docker push "${IMAGE}:${BUILD_NUMBER}"
docker push "${IMAGE}:latest"
