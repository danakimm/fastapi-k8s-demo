#!/usr/bin/env bash
set -euo pipefail

: "${NEXUS_REGISTRY:?NEXUS_REGISTRY가 필요합니다}"
: "${DOCKER_IMAGE:?DOCKER_IMAGE가 필요합니다}"
: "${IMAGE_TAG:?IMAGE_TAG가 필요합니다}"
: "${KUBE_API_URL:?KUBE_API_URL이 필요합니다}"
: "${KUBE_NAMESPACE:?KUBE_NAMESPACE가 필요합니다}"
: "${KUBE_CA_B64:?KUBE_CA_B64가 필요합니다}"
: "${KUBE_TOKEN:?KUBE_TOKEN이 필요합니다}"

HELM_RELEASE="${HELM_RELEASE:-fastapi-pg}"
IMAGE_REPOSITORY="${NEXUS_REGISTRY}/${DOCKER_IMAGE}"
TEMP_DIR="$(mktemp -d)"
PORT_FORWARD_PID=""

cleanup() {
  if [[ -n "${PORT_FORWARD_PID}" ]]; then
    kill "${PORT_FORWARD_PID}" >/dev/null 2>&1 || true
  fi
  rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

printf '%s' "${KUBE_CA_B64}" | base64 --decode > "${TEMP_DIR}/ca.crt"

cat > "${TEMP_DIR}/kubeconfig" <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: k3s
    cluster:
      server: ${KUBE_API_URL}
      certificate-authority: ${TEMP_DIR}/ca.crt
users:
  - name: teamcity-deployer
    user:
      token: ${KUBE_TOKEN}
contexts:
  - name: teamcity-deployer@k3s
    context:
      cluster: k3s
      user: teamcity-deployer
      namespace: ${KUBE_NAMESPACE}
current-context: teamcity-deployer@k3s
EOF
chmod 600 "${TEMP_DIR}/kubeconfig" "${TEMP_DIR}/ca.crt"
export KUBECONFIG="${TEMP_DIR}/kubeconfig"

kubectl auth can-i patch deployments --namespace "${KUBE_NAMESPACE}" | grep -qx yes

POSTGRES_SECRET="${HELM_RELEASE}-postgres"
POSTGRES_PASSWORD_B64="$(
  kubectl get secret "${POSTGRES_SECRET}" \
    --namespace "${KUBE_NAMESPACE}" \
    --output jsonpath='{.data.POSTGRES_PASSWORD}' 2>/dev/null || true
)"

if [[ -n "${POSTGRES_PASSWORD_B64}" ]]; then
  POSTGRES_PASSWORD="$(printf '%s' "${POSTGRES_PASSWORD_B64}" | base64 --decode)"
else
  POSTGRES_PASSWORD="$(python3 -c 'import secrets; print(secrets.token_hex(24))')"
fi

helm upgrade --install "${HELM_RELEASE}" ./chart \
  --namespace "${KUBE_NAMESPACE}" \
  --set "api.image.repository=${IMAGE_REPOSITORY}" \
  --set-string "api.image.tag=${IMAGE_TAG}" \
  --set "ingress.className=traefik" \
  --set-string "postgres.auth.password=${POSTGRES_PASSWORD}" \
  --atomic \
  --wait \
  --timeout 5m

kubectl rollout status "deployment/${HELM_RELEASE}-api" \
  --namespace "${KUBE_NAMESPACE}" \
  --timeout 120s

kubectl port-forward "service/${HELM_RELEASE}-api" 18080:80 \
  --namespace "${KUBE_NAMESPACE}" \
  > "${TEMP_DIR}/port-forward.log" 2>&1 &
PORT_FORWARD_PID="$!"

curl --fail --silent --show-error \
  --retry 15 \
  --retry-all-errors \
  --retry-delay 2 \
  http://127.0.0.1:18080/health
echo

echo "Deployed ${IMAGE_REPOSITORY}:${IMAGE_TAG} to ${KUBE_NAMESPACE}"
