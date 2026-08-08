# mockctl CLI (optional / legacy)

> **Recommended path for learners:** Docker Desktop Kubernetes + [`mockctl-web`](../README.md) (one-liner on the main README).  
> You do **not** need this CLI for the normal course flow.

`mockctl` is a small Go CLI that used to drive a **minikube** profile (`mock-exams`), install tools, and serve courses. It is still useful for maintainers and for environments without Docker Desktop Kubernetes.

## What it can do

| Command | Purpose |
|---------|---------|
| `install` | Install **minikube** + **kubectl** (winget / brew / `~/.local/bin`) |
| `up` | Start minikube profile `mock-exams` (Docker driver), optional addons |
| `down` | Delete profile (`--soft` = stop only) |
| `status` | Cluster + kubeconfig refresh |
| `kubeconfig` | Rewrite `output/kubeconfig.yaml` |
| `web` | Local courses UI (`127.0.0.1:8091` by default) |
| `localstack` | AWS emulator for terraform labs (no Kubernetes) |
| `clean` / `uninstall` | Reset / remove tools |

Useful `up` flags (minikube era):

- `--no-addons` — skip metrics-server / ingress  
- `--nodes N` — multi-node  
- `--lb` — edge nginx on localhost → Ingress NodePort  
- `--gitlab` — GitLab CE + runner for CI courses  

Profile name override: env **`MOCKCTL_PROFILE`** (default `mock-exams`).

## Typical usage (minikube)

```text
mockctl install
mockctl up
mockctl status
mockctl web
mockctl down
```

Requires **Docker** running (`docker info`).

## Interactive labs

If a lesson has a sibling `*.lab.json`, `mockctl web` shows **Start lab / Check / Cleanup**.  
The engine uses `kubectl` against the configured kubeconfig.

## Binaries

Cross-platform builds historically lived under `mockctl/dist/` in the source repo (Windows / Linux / macOS amd64+arm64), including optional **`-embed`** builds with courses baked in.

## Prefer Docker Desktop instead

For Windows (especially Smart App Control) and for a stable student experience:

1. Enable Kubernetes in Docker Desktop  
2. Run the [bootstrap one-liner](../README.md)  
3. Open http://127.0.0.1:8091/  

That path uses the **`mockctl-web` container**, not a local `mockctl.exe`.
