#!/usr/bin/env bash
# Courses UI only — no Kubernetes.
#
#   curl -fsSL https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main/unix-courses-ui.sh | bash
#
# Serves http://127.0.0.1:8091/  (lessons + Interactive Check for LocalStack labs).

set -euo pipefail

IMAGE="${MOCKCTL_WEB_IMAGE:-ghcr.io/fedorarbuzov/mock-exams/mockctl-web:latest}"
PORT="${MOCKCTL_WEB_PORT:-8091}"
CONTAINER="mockctl-web"
URL="http://127.0.0.1:${PORT}/"

echo "Checking Docker..."
if ! docker version --format '{{.Server.Version}}' >/dev/null 2>&1; then
  echo "Start Docker Desktop (or the Docker daemon) first." >&2
  exit 1
fi

echo "Pulling $IMAGE ..."
if ! docker pull "$IMAGE"; then
  if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "Image not found: $IMAGE" >&2
    exit 1
  fi
  echo "Pull failed; using the image already on disk."
fi

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

run_args=(
  -d
  --name "$CONTAINER"
  --restart unless-stopped
  -p "${PORT}:8091"
)
if [ "$(uname -s)" = "Linux" ]; then
  run_args+=(--add-host host.docker.internal:host-gateway)
fi

docker run "${run_args[@]}" "$IMAGE"

echo "Waiting for courses UI on $URL ..."
deadline=$((SECONDS + 120))
ready=0
while (( SECONDS < deadline )); do
  code=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 3 "$URL" 2>/dev/null || echo "000")
  if [[ "$code" =~ ^[23] ]]; then
    ready=1
    break
  fi
  echo "  still starting..."
  sleep 2
done

if [[ "$ready" -ne 1 ]]; then
  echo "Courses UI not up after 2 min. Check: docker logs $CONTAINER" >&2
  exit 1
fi

echo
echo "OK  $URL"
echo "Stop: docker rm -f $CONTAINER"
