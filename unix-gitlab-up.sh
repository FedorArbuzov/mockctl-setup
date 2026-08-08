#!/usr/bin/env bash
# GitLab CE + runner in one shot (Docker Desktop / Docker Engine).
#
#   curl -fsSL https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main/unix-gitlab-up.sh | bash
#
# First boot: 5–15 minutes. Needs ~4–6 GB RAM free for GitLab.

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main"
DIR="${HOME}/.mock-exams/gitlab"
COMPOSE="${DIR}/docker-compose.yml"
GITLAB="mock-gitlab"
RUNNER="mock-gitlab-runner"
URL="http://localhost:8929"

echo "Checking Docker..."
if ! docker info >/dev/null 2>&1; then
  echo "Start Docker Desktop (or the Docker daemon) first." >&2
  exit 1
fi

mkdir -p "$DIR"
echo "Fetching compose -> $COMPOSE"
curl -fsSL "$REPO_RAW/gitlab/docker-compose.yml" -o "$COMPOSE"

echo "Starting GitLab stack (first pull can take a while)..."
docker compose -f "$COMPOSE" up -d

echo "Waiting for GitLab (puma + sidekiq). This can take 5–15 min on first boot..."
ready=0
for _ in $(seq 1 80); do
  if ! docker inspect -f '{{.State.Running}}' "$GITLAB" 2>/dev/null | grep -qx true; then
    echo "  container not running yet..."
    sleep 15
    continue
  fi
  status="$(docker exec "$GITLAB" gitlab-ctl status 2>/dev/null || true)"
  if echo "$status" | grep -q 'run: puma' && echo "$status" | grep -q 'run: sidekiq'; then
    ready=1
    break
  fi
  echo "  still starting..."
  sleep 15
done

if [ "$ready" -ne 1 ]; then
  echo "GitLab not ready after ~20 min. Check: docker exec $GITLAB gitlab-ctl status" >&2
  exit 1
fi

echo "GitLab is up. Bootstrapping runner..."
cfg="$(docker exec "$RUNNER" cat /etc/gitlab-runner/config.toml 2>/dev/null || true)"
if echo "$cfg" | grep -q '\[\[runners\]\]' && echo "$cfg" | grep -q 'http://gitlab'; then
  echo "Runner already registered — skip."
else
  token="$(docker exec "$GITLAB" gitlab-rails runner \
    "puts Gitlab::CurrentSettings.current_application_settings.runners_registration_token" 2>/dev/null | tail -n 1 | tr -d '\r')"
  if [ -z "$token" ]; then
    echo "Empty registration token. Register manually — see README." >&2
    exit 1
  fi
  if docker exec "$RUNNER" gitlab-runner register \
      --non-interactive \
      --url http://gitlab \
      --token "$token" \
      --executor docker \
      --docker-image alpine:latest \
      --description "local-docker" \
      --tag-list "docker,local" \
      --docker-network-mode host; then
    echo "Registered runner tags: docker, local"
  else
    echo "WARNING: auto-register failed. Register manually (see README)." >&2
  fi
fi

echo ""
echo "OK  $URL"
echo "Login: root"
echo "Password (first boot only):"
echo "  docker exec $GITLAB grep 'Password:' /etc/gitlab/initial_root_password"
echo "Stop (keep data): docker compose -f \"$COMPOSE\" down"
echo "Wipe data:        docker compose -f \"$COMPOSE\" down -v"
