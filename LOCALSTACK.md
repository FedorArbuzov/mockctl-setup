# AWS + Terraform labs — local setup

How to run the **aws-terraform** course without Kubernetes, minikube, or a real AWS account.

You need **Docker Desktop** (or Docker Engine). One command starts:

- **LocalStack** on **http://localhost:4566**
- **`lab`** — Terraform + AWS CLI, files in **`~/aws-labs`**

No Terraform or AWS CLI install on the host is required to do the labs (use `exec lab bash`). Interactive Check in the courses UI still uses the **UI / host** `aws` if you run Check there.

The first run **builds** the lab image on your machine (a few minutes). It pulls only the public LocalStack image — no GitHub Container Registry login.

---

## One command

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main/windows-localstack-up.ps1 | iex
```

If execution policy blocks scripts:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main/unix-localstack-up.sh | bash
```

The script:

1. Writes compose + lab Dockerfile to `~/.mock-exams/localstack/` (Windows: `%USERPROFILE%\.mock-exams\localstack\`)
2. Creates `~/aws-labs`
3. Pulls **`localstack/localstack:3.8`**
4. Builds **`mock-aws-terraform-lab:local`** (Terraform + AWS CLI)
5. Starts both containers
6. Waits until **http://localhost:4566/_localstack/health** returns 200

Expected last lines:

```text
OK  LocalStack  http://localhost:4566
    workdir:    .../aws-labs
    lab:        docker compose -f ... exec lab bash
```

Enter the toolbox:

```bash
docker compose -f ~/.mock-exams/localstack/docker-compose.yml exec lab bash
```

PowerShell:

```powershell
docker compose -f "$env:USERPROFILE\.mock-exams\localstack\docker-compose.yml" exec lab bash
```

Inside `lab`, `localhost:4566` is LocalStack (same URLs as in the course). You are in `/aws-labs`.

**Port 4566** — only one LocalStack at a time.

---

## Courses UI (lessons + Interactive Check)

Skip the [main README](README.md) one-liner — that path needs Kubernetes.

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main/windows-courses-ui.ps1 | iex
```

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main/unix-courses-ui.sh | bash
```

Then **http://127.0.0.1:8091/** → **aws-terraform**. Keep the LocalStack+lab stack up while you **Check**.

---

## Optional: tools on the host

If you prefer `terraform` / `aws` on the laptop instead of `lab`: [Install Terraform](https://developer.hashicorp.com/terraform/install), [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html). Fake keys: `test` / `test` / `us-east-1`.

Interactive Check needs `aws` where the UI runs (host `mockctl web`, or already inside the Docker courses UI).

---

## Stop / reset

```bash
docker compose -f "$HOME/.mock-exams/localstack/docker-compose.yml" down
```

Windows:

```powershell
docker compose -f "$env:USERPROFILE\.mock-exams\localstack\docker-compose.yml" down
```

Wipe LocalStack data: add `-v`. `~/aws-labs` is on the host and is not deleted.

---

## Troubleshooting

| Symptom | What to do |
|---------|------------|
| `irm : 404` | URL must be `.../mockctl-setup/main/windows-localstack-up.ps1` |
| lab image **denied** / 401 | Old script tried to pull a private GHCR image. Re-run the one-liner (it now builds locally). |
| `License activation failed` | Pin is **3.8**, not `latest`. Delete `~/.mock-exams/localstack/` and re-run |
| Port 4566 in use | Stop the other LocalStack (`docker ps`, then `compose down`) |
| Courses UI asks for Kubernetes | You used the **K8s** one-liner. Use `windows-courses-ui.ps1` / `unix-courses-ui.sh` |

Course details: [aws-terraform ENVIRONMENT](https://github.com/FedorArbuzov/mock-exams/blob/master/courses-en/aws-terraform/ENVIRONMENT.md) (after that file is on `master`).
