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
LAB_DIR="${DIR}/lab"
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

resolve_local_lab() {
  local d
  for d in \
    "${script_dir}/../deploy/aws-terraform/lab" \
    "${script_dir}/localstack/lab"
  do
    if [[ -n "$script_dir" && -f "$d/Dockerfile" ]]; then
      (cd "$d" && pwd)
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
  if curl -fsSL "$REPO_RAW/localstack/docker-compose.yml" -o "$COMPOSE"; then
    return 0
  fi
  if curl -fsSL "$EXAMS_RAW/deploy/aws-terraform/docker-compose.yml" -o "$COMPOSE"; then
    return 0
  fi
  echo "Could not get docker-compose.yml. Run from the mock-exams repo: bash scripts/unix-localstack-up.sh" >&2
  exit 1
}

install_lab_files() {
  mkdir -p "$LAB_DIR"
  local local_lab
  if local_lab="$(resolve_local_lab)"; then
    echo "Using local lab context $local_lab"
    cp "$local_lab/Dockerfile" "$local_lab/entrypoint.sh" "$local_lab/verify-final.sh" "$local_lab/lab-help" "$LAB_DIR/"
    if [[ -f "$local_lab/.dockerignore" ]]; then
      cp "$local_lab/.dockerignore" "$LAB_DIR/"
    fi
    return 0
  fi
  echo "Fetching lab Dockerfile -> $LAB_DIR"
  local f
  for f in Dockerfile entrypoint.sh verify-final.sh lab-help .dockerignore; do
    if ! curl -fsSL "$REPO_RAW/localstack/lab/$f" -o "$LAB_DIR/$f"; then
      echo "Could not fetch lab/$f from mockctl-setup." >&2
      exit 1
    fi
  done
}

echo "Checking Docker..."
if ! docker info >/dev/null 2>&1; then
  echo "Start Docker Desktop (or the Docker daemon) first." >&2
  exit 1
fi

install_compose_file
install_lab_files
mkdir -p "$LABS"

# Leftover LocalStack-only one-liner used a different container name.
docker rm -f localstack-localstack-1 mock-aws-terraform-localstack mock-aws-terraform-lab >/dev/null 2>&1 || true

echo "Pulling LocalStack..."
if ! docker compose -f "$COMPOSE" pull localstack; then
  echo "LocalStack image pull failed." >&2
  exit 1
fi

if [[ -n "${AWS_TERRAFORM_LAB_IMAGE:-}" ]]; then
  echo "Pulling lab image $AWS_TERRAFORM_LAB_IMAGE ..."
  if ! docker compose -f "$COMPOSE" pull lab; then
    echo "Lab image pull failed. Unset AWS_TERRAFORM_LAB_IMAGE to build locally." >&2
    exit 1
  fi
else
  echo "Building lab image (Terraform + AWS CLI; first time can take a few minutes)..."
  if ! docker compose -f "$COMPOSE" build lab; then
    echo "Lab image build failed." >&2
    exit 1
  fi
fi

echo "Starting LocalStack + lab..."
docker compose -f "$COMPOSE" up -d --no-build

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
echo "    health:     $URL/_localstack/health"
echo "    workdir:    $LABS"
echo "    lab:        docker compose -f $COMPOSE exec lab bash"
echo "    terraform:  docker compose -f $COMPOSE exec lab terraform version"
echo "    stop:       docker compose -f $COMPOSE down"
echo "    (LocalStack data volume is kept; add -v to wipe)"
