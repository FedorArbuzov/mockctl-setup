# mockctl-setup

**Learn Kubernetes and other tech hands-on — without setting up a complicated lab yourself or paying monthly for a cloud sandbox.**

All you need:

1. Install **Docker Desktop**
2. Turn on **Kubernetes** inside it
3. Run **one command**

After that, open the browser and go through lessons and interactive labs (Start / Check / Cleanup) against a real local cluster.

No cloud account. No admin rights. About **5 GB** free disk and internet for the first image pull.

---

## What happens after the one command

The script starts **`mockctl-web`**: a small container with the courses UI and `kubectl`. It talks to your Docker Desktop Kubernetes.

Then open: **http://127.0.0.1:8091/**

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

---

## Step 3. One command

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main/windows-mockctl-web.ps1 | iex
```

If execution policy blocks scripts:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main/unix-mockctl-web.sh | bash
```

Expected:

```text
OK  http://127.0.0.1:8091/
```

---

## Step 4. Open courses

**http://127.0.0.1:8091/**

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

## License / source

Course content and image builds live in a private source repo.  
This public repo is the **install + share** surface (scripts + setup docs).
