#!/usr/bin/env bash
# Docker Desktop K8s + mockctl-web in one shot.
#
#   curl -fsSL https://raw.githubusercontent.com/FedorArbuzov/mock-exams-win/main/unix-mockctl-web.sh | bash
#
# Before running: Docker Desktop -> Settings -> Kubernetes -> Enable Kubernetes.

set -euo pipefail

IMAGE="${MOCKCTL_WEB_IMAGE:-ghcr.io/fedorarbuzov/mock-exams/mockctl-web:latest}"
PORT="${MOCKCTL_WEB_PORT:-8091}"
KUBECONFIG_HOST="${HOME}/.mock-exams/kubeconfig.yaml"
CONTAINER="mockctl-web"

if ! docker info >/dev/null 2>&1; then
  echo "Start Docker Desktop first." >&2
  exit 1
fi

if ! kubectl config get-contexts -o name 2>/dev/null | grep -qx 'docker-desktop'; then
  echo "Enable Kubernetes in Docker Desktop (Settings -> Kubernetes -> Enable Kubernetes)." >&2
  exit 1
fi

kubectl config use-context docker-desktop >/dev/null
kubectl get nodes

mkdir -p "$(dirname "$KUBECONFIG_HOST")"
kubectl config view --minify --flatten --context=docker-desktop >"$KUBECONFIG_HOST"

if ! docker pull "$IMAGE" >/dev/null 2>&1; then
  if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "Image not found: $IMAGE" >&2
    exit 1
  fi
fi

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

run_args=(
  -d
  --name "$CONTAINER"
  --restart unless-stopped
  -p "${PORT}:8091"
  -v "${KUBECONFIG_HOST}:/kube/host-kubeconfig.yaml:ro"
)
# Linux Docker Desktop: reach host API via host.docker.internal.
# macOS Docker Desktop already provides host.docker.internal.
if [ "$(uname -s)" = "Linux" ]; then
  run_args+=(--add-host host.docker.internal:host-gateway)
fi

docker run "${run_args[@]}" "$IMAGE"

sleep 2
if ! docker exec "$CONTAINER" kubectl --kubeconfig=/work/output/kubeconfig.yaml get nodes; then
  echo "Container cannot reach the cluster. docker logs $CONTAINER" >&2
  exit 1
fi

echo ""
echo "OK  http://127.0.0.1:${PORT}/"
echo "Stop: docker rm -f $CONTAINER"
