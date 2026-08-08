# GitLab CI/CD labs — local setup

How to run the **GitLab CI/CD** course labs without `mockctl`.

You need **Docker** and about **4–6 GB RAM** free for GitLab (8+ GB is comfortable if Docker Desktop Kubernetes is also enabled).

---

## One command

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main/windows-gitlab-up.ps1 | iex
```

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main/unix-gitlab-up.sh | bash
```

The script:

1. Downloads `gitlab/docker-compose.yml` to `~/.mock-exams/gitlab/` (Windows: `%USERPROFILE%\.mock-exams\gitlab\`)
2. Starts **GitLab CE** + **gitlab-runner** (`docker compose up -d`)
3. Waits until GitLab is ready (first boot often **5–15 minutes**)
4. Registers a Docker executor runner with tags **`docker`**, **`local`** (if not already registered)

Expected last line:

```text
OK  http://localhost:8929/
```

---

## First login

1. Open **http://localhost:8929**
2. User: **`root`**
3. Password (first boot only):

```bash
docker exec mock-gitlab grep 'Password:' /etc/gitlab/initial_root_password
```

Save it — GitLab removes that file after 24 hours.

Check the runner: **Admin → CI/CD → Runners** (or project **Settings → CI/CD → Runners**) — should be **online** with tags `docker`, `local`.

---

## Courses UI (lessons)

GitLab labs are in the **courses** app (same as Kubernetes basic):

1. Complete the [main setup](README.md) (Docker Desktop + Kubernetes + courses one-liner) if you have not already.
2. Open **http://127.0.0.1:8091/**
3. Open the **gitlab-cicd** course and follow lessons from **00 — Environment** onward.

You can do **Part A** (pipelines, tests, artifacts) with **GitLab only**.  
**Deploy** and **review app** lessons also need **Kubernetes** (Step 2 in the main README).

---

## Kubernetes for deploy labs

For lessons that run `kubectl` from CI (deploy, environments, review apps, final project):

1. Enable Kubernetes in Docker Desktop (see [main README](README.md)).
2. Install **ingress-nginx** as LoadBalancer (same as kuber-basic final):

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer
```

3. Hit apps at **http://127.0.0.1/** (not `localhost` on Windows if IPv6 hangs).

4. In GitLab project **Settings → CI/CD → Variables**, add **`KUBECONFIG`** as type **File**:
   - Export kubeconfig on the host:
     ```bash
     kubectl config view --minify --flatten --context=docker-desktop > kubeconfig-for-gitlab.yaml
     ```
   - Paste file contents into the variable (masked/protected as your course requires).
   - If deploy jobs cannot reach the API server, change `server:` in that file to `https://host.docker.internal:<port>` (port from `kubectl cluster-info`).

---

## Typical lab flow

1. Create a project in GitLab (e.g. `platform-hello`).
2. Copy an example from the lesson (`examples/hello-ci` or `examples/k8s-deploy` in the course).
3. Push to GitLab; pipeline runs on the runner.
4. Fix `.gitlab-ci.yml` until jobs are green.
5. For deploy labs: image in GitLab Container Registry → `kubectl apply` / rollout in CI.

---

## Stop / reset

**Stop GitLab (keep data):**

```bash
docker compose -f "$HOME/.mock-exams/gitlab/docker-compose.yml" down
```

Windows:

```powershell
docker compose -f "$env:USERPROFILE\.mock-exams\gitlab\docker-compose.yml" down
```

**Remove all GitLab data:**

```bash
docker compose -f "$HOME/.mock-exams/gitlab/docker-compose.yml" down -v
```

**Courses UI** (separate):

```bash
docker rm -f mockctl-web
```

---

## Troubleshooting

| Symptom | What to do |
|---------|------------|
| `502` / blank page for minutes | First boot — wait; `docker exec mock-gitlab gitlab-ctl status` until puma + sidekiq are `run:` |
| GitLab very slow / exits | Not enough RAM — free memory or raise Docker Desktop limit (4–6 GB+ for GitLab) |
| No runner online | Re-run the one-liner, or register manually (see below) |
| Pipeline: `connection refused` to Kubernetes | Fix `KUBECONFIG` server URL (`host.docker.internal`) |
| Job stuck `pending` | Runner offline or missing tags `docker` / `local` in `.gitlab-ci.yml` |

### Manual runner register

If auto-register failed:

```bash
docker exec -it mock-gitlab-runner gitlab-runner register \
  --url http://gitlab \
  --token YOUR_TOKEN \
  --executor docker \
  --docker-image alpine:latest \
  --description "local-docker" \
  --non-interactive \
  --tag-list "docker,local" \
  --docker-network-mode host
```

Get `YOUR_TOKEN` from GitLab **Admin → CI/CD → Runners** (or project runners page).

---

## Files in this repo

| File | Purpose |
|------|---------|
| [`windows-gitlab-up.ps1`](windows-gitlab-up.ps1) | Bootstrap (Windows) |
| [`unix-gitlab-up.sh`](unix-gitlab-up.sh) | Bootstrap (macOS / Linux) |
| [`gitlab/docker-compose.yml`](gitlab/docker-compose.yml) | GitLab CE + runner stack |

Main courses setup (Kubernetes + UI): [README.md](README.md)
