#!/usr/bin/env bash
# LocalStack in one shot (Docker Desktop / Docker Engine). No Kubernetes.
#
#   curl -fsSL https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main/unix-localstack-up.sh | bash
#
# Endpoint: http://localhost:4566

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main"
DIR="${HOME}/.mock-exams/localstack"
COMPOSE="${DIR}/docker-compose.yml"
CONTAINER="localstack-localstack-1"
URL="http://localhost:4566"

script_dir=""
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || true
fi

resolve_local_compose() {
  local c
  for c in \
    "${script_dir}/localstack/docker-compose.yml" \
    "${script_dir}/../deploy/localstack/docker-compose.yml"
  do
    if [[ -n "$script_dir" && -f "$c" ]]; then
      (cd "$(dirname "$c")" && pwd)/$(basename "$c")
      return 0
    fi
  done
  return 1
}

install_compose_file() {
  mkdir -p "$DIR"
  local local_file
  if local_file="$(resolve_local_compose)"; then
    echo "Using local compose $local_file"
    cp "$local_file" "$COMPOSE"
    return 0
  fi
  echo "Fetching compose -> $COMPOSE"
  curl -fsSL "$REPO_RAW/localstack/docker-compose.yml" -o "$COMPOSE"
}

echo "Checking Docker..."
if ! docker info >/dev/null 2>&1; then
  echo "Start Docker Desktop (or the Docker daemon) first." >&2
  exit 1
fi

install_compose_file

# Replace a leftover container with the same name (e.g. a previous docker run).
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

echo "Starting LocalStack..."
docker compose -f "$COMPOSE" up -d

echo "Waiting for LocalStack health on $URL ..."
deadline=$((SECONDS + 300))
ready=0
while (( SECONDS < deadline )); do
  if docker inspect "$CONTAINER" >/dev/null 2>&1; then
    running="$(docker inspect -f '{{.State.Running}}' "$CONTAINER")"
    if [[ "$running" != "true" ]]; then
      echo "LocalStack exited. If logs mention a license / AUTH_TOKEN, the image is too new — this stack pins localstack/localstack:3.8." >&2
      docker compose -f "$COMPOSE" logs --tail 40 >&2 || true
      exit 1
    fi
  fi
  code=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 3 \
    "$URL/_localstack/health" 2>/dev/null || echo "000")
  if [[ "$code" == "200" ]]; then
    ready=1
    break
  fi
  echo "  still starting..."
  sleep 3
done

if [[ "$ready" -ne 1 ]]; then
  echo "LocalStack not healthy after 5 min. Check: docker compose -f $COMPOSE logs" >&2
  exit 1
fi

echo
echo "OK  LocalStack  $URL"
echo "    health:     $URL/_localstack/health"
echo "    stop:       docker compose -f $COMPOSE down"
echo "    (data volume is kept; add -v to wipe)"
