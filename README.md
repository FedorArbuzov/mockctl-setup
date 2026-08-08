# mock-exams — local Kubernetes courses

Hands-on Kubernetes (and related) labs in the browser, against **Docker Desktop Kubernetes**.

No admin rights required. You need internet access and about **5 GB** free disk.

> **LinkedIn / share link:** this README is the public setup guide.

---

## What you get

1. Docker Desktop Kubernetes on your machine  
2. One command that starts **`mockctl-web`** (courses UI + `kubectl` in a container)  
3. Open **http://127.0.0.1:8091/** — lessons, labs, Start / Check / Cleanup  

Image: `ghcr.io/fedorarbuzov/mock-exams/mockctl-web:latest`

---

## Step 1. Install Docker Desktop

| OS | Link |
|----|------|
| Windows | https://docs.docker.com/desktop/setup/install/windows-install/ |
| macOS | https://docs.docker.com/desktop/setup/install/mac-install/ |
| Linux | https://docs.docker.com/desktop/setup/install/linux-install/ |

Start Docker Desktop and wait until status is **Docker is running**.

```bash
docker info
```

<!-- Screenshot: Docker Desktop running -->
<!-- ![Docker Desktop running](docs/screenshots/01-docker-running.png) -->

---

## Step 2. Enable Kubernetes

1. Open **Docker Desktop** → **Settings** → **Kubernetes**  
2. Enable **Kubernetes**  
3. **Apply & Restart** / **Create cluster**  
4. Wait until the cluster is ready (1–3 minutes)

```bash
kubectl config use-context docker-desktop
kubectl get nodes
```

Nodes should be **Ready**.

<!-- Screenshot: Kubernetes enabled -->
<!-- ![Kubernetes ready](docs/screenshots/02-k8s-ready.png) -->

---

## Step 3. One command

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/FedorArbuzov/mock-exams-win/main/windows-mockctl-web.ps1 | iex
```

If execution policy blocks scripts:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/FedorArbuzov/mock-exams-win/main/unix-mockctl-web.sh | bash
```

Expected:

```text
OK  http://127.0.0.1:8091/
```

<!-- Screenshot: terminal OK line -->
<!-- ![Bootstrap OK](docs/screenshots/03-bootstrap-ok.png) -->

---

## Step 4. Open courses

**http://127.0.0.1:8091/**

<!-- Screenshot: courses UI -->
<!-- ![Courses UI](docs/screenshots/04-courses-ui.png) -->

---

## Stop

```bash
docker rm -f mockctl-web
```

Kubernetes in Docker Desktop stays enabled.

---

## Optional settings

| Variable | Meaning | Default |
|----------|---------|---------|
| `MOCKCTL_WEB_IMAGE` | Container image | `ghcr.io/fedorarbuzov/mock-exams/mockctl-web:latest` |
| `MOCKCTL_WEB_PORT` | Host port | `8091` |

**Windows:** `$env:MOCKCTL_WEB_PORT = 9091`  
**macOS / Linux:** `export MOCKCTL_WEB_PORT=9091`

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Start Docker Desktop first | Start Docker Desktop, retry |
| Enable Kubernetes… | Settings → Kubernetes → enable, wait for Ready |
| Browser: site can't be reached | `docker pull …/mockctl-web:latest`, remove container, rerun one-liner |
| Port 8091 busy | Set `MOCKCTL_WEB_PORT` (see above) |

---

## Repo layout

| File | Purpose |
|------|---------|
| [`windows-mockctl-web.ps1`](windows-mockctl-web.ps1) | Windows bootstrap |
| [`unix-mockctl-web.sh`](unix-mockctl-web.sh) | macOS / Linux bootstrap |
| [`docs/mockctl.md`](docs/mockctl.md) | Optional **CLI** (`mockctl`) notes — minikube-era tool; **not** required for the Docker Desktop path above |

---

## Screenshots for LinkedIn

Add PNGs under [`docs/screenshots/`](docs/screenshots/) and uncomment the image lines in this README:

1. Docker Desktop running  
2. Kubernetes Ready (`kubectl get nodes`)  
3. Bootstrap `OK http://127.0.0.1:8091/`  
4. Courses UI in the browser  

---

## License / source

Course content and image builds live in a private source repo.  
This public repo is the **install + share** surface (scripts + setup docs).
