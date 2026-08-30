#!/usr/bin/env bash
# LocalStack + aws-terraform lab (Terraform, AWS CLI) in one shot. No Kubernetes.
#
# From this repo:
#   bash scripts/unix-localstack-up.sh
#
# Public:
#   curl -fsSL https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main/unix-localstack-up.sh | bash
#
# LocalStack: http://localhost:4566
# Lab:        docker compose -f ~/.mock-exams/localstack/docker-compose.yml exec lab bash
# Workdir:    ~/aws-labs

set -euo pipefail

REPO_RAW="${MOCKCTL_SETUP_RAW:-https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main}"
EXAMS_RAW="${MOCK_EXAMS_RAW:-https://raw.githubusercontent.com/FedorArbuzov/mock-exams/master}"
DIR="${HOME}/.mock-exams/localstack"
COMPOSE="${DIR}/docker-compose.yml"
URL="http://localhost:4566"
LABS="${HOME}/aws-labs"

script_dir=""
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || true
fi

resolve_local_compose() {
  local c
  for c in \
    "${script_dir}/../deploy/aws-terraform/docker-compose.yml" \
    "${script_dir}/localstack/docker-compose.yml"
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
  if curl -fsSL "$EXAMS_RAW/deploy/aws-terraform/docker-compose.yml" -o "$COMPOSE"; then
    return 0
  fi
  if curl -fsSL "$REPO_RAW/localstack/docker-compose.yml" -o "$COMPOSE"; then
    return 0
  fi
  echo "Could not get docker-compose.yml. Run from the mock-exams repo: bash scripts/unix-localstack-up.sh" >&2
  exit 1
}

echo "Checking Docker..."
if ! docker info >/dev/null 2>&1; then
  echo "Start Docker Desktop (or the Docker daemon) first." >&2
  exit 1
fi

install_compose_file
mkdir -p "$LABS"

# Leftover LocalStack-only one-liner used a different container name.
docker rm -f localstack-localstack-1 mock-aws-terraform-localstack mock-aws-terraform-lab >/dev/null 2>&1 || true

echo "Pulling images (LocalStack + lab)..."
if ! docker compose -f "$COMPOSE" pull; then
  echo "Image pull failed. If aws-terraform-lab is 401/denied, make the GHCR package Public." >&2
  exit 1
fi

echo "Starting LocalStack + lab..."
docker compose -f "$COMPOSE" up -d

echo "Waiting for LocalStack health on $URL ..."
deadline=$((SECONDS + 300))
ready=0
while (( SECONDS < deadline )); do
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
  docker compose -f "$COMPOSE" logs --tail 40 >&2 || true
  exit 1
fi

if ! docker inspect -f '{{.State.Running}}' mock-aws-terraform-lab 2>/dev/null | grep -qx true; then
  echo "Lab container is not running. Check: docker compose -f $COMPOSE logs lab" >&2
  docker compose -f "$COMPOSE" logs --tail 40 lab >&2 || true
  exit 1
fi

echo
echo "OK  LocalStack  $URL"
echo "    course:     http://127.0.0.1:8091/aws-terraform/README.md"
echo "    health:     $URL/_localstack/health"
echo "    workdir:    $LABS"
echo "    lab:        docker compose -f $COMPOSE exec lab bash"
echo "    terraform:  docker compose -f $COMPOSE exec lab terraform version"
echo "    stop:       docker compose -f $COMPOSE down"
echo "    (LocalStack data volume is kept; add -v to wipe)"
if curl -sf --connect-timeout 2 "http://127.0.0.1:8091/" >/dev/null 2>&1; then
  echo
  echo "Open the course:  http://127.0.0.1:8091/aws-terraform/README.md"
else
  echo
  echo "Lessons UI is not running yet. Start it, then open the course URL:"
  echo "  curl -fsSL https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main/unix-courses-ui.sh | bash"
  echo "  http://127.0.0.1:8091/aws-terraform/README.md"
fi
