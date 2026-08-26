# AWS + Terraform labs — local setup

How to run the **aws-terraform** course without Kubernetes, minikube, or a real AWS account.

You need **Docker Desktop** (or Docker Engine). LocalStack is an AWS emulator on **http://localhost:4566**. Terraform runs **on your laptop**.

---

## One command (LocalStack)

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

1. Downloads [`localstack/docker-compose.yml`](localstack/docker-compose.yml) to `~/.mock-exams/localstack/` (Windows: `%USERPROFILE%\.mock-exams\localstack\`)
2. Starts LocalStack (`docker compose up -d`) — image **`localstack/localstack:3.8`** (community; `latest` may demand an auth token)
3. Waits until **http://localhost:4566/_localstack/health** returns 200

Expected last lines:

```text
OK  LocalStack  http://localhost:4566
    health:     http://localhost:4566/_localstack/health
```

Sanity check:

```bash
curl -s http://localhost:4566/_localstack/health
```

PowerShell:

```powershell
Invoke-WebRequest http://localhost:4566/_localstack/health -UseBasicParsing
```

You should see JSON with `"s3"` / `"lambda"` / `"dynamodb"` available.

**Port 4566** — only one LocalStack at a time.

---

## Install Terraform

The CLI is **not** inside the LocalStack container. Need **1.5 or newer**.

Official instructions (zip for every OS, Linux apt/yum): [developer.hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install).

**Windows** (PowerShell) — id is `Hashicorp.Terraform` (lowercase `c`; `-e` is case-sensitive):

```powershell
winget install --id Hashicorp.Terraform -e
```

Open a **new** terminal, then `terraform version`.

**macOS:**

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform version
```

**Linux:** follow the HashiCorp install page, or unpack a zip into `/usr/local/bin`.

---

## Fake AWS credentials (for this course)

LocalStack accepts any keys. In the same terminal you use for `terraform` / `aws`:

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
```

PowerShell:

```powershell
$env:AWS_ACCESS_KEY_ID = "test"
$env:AWS_SECRET_ACCESS_KEY = "test"
$env:AWS_DEFAULT_REGION = "us-east-1"
```

AWS CLI v2 is optional on the host (`aws --endpoint-url=http://localhost:4566 s3 ls`). Interactive Check in the UI uses AWS CLI **inside** the courses container.

---

## Courses UI (lessons + Interactive Check)

Skip the [main README](README.md) one-liner — that path needs Kubernetes. This course does not.

Start the same courses UI **without a cluster**:

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main/windows-courses-ui.ps1 | iex
```

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main/unix-courses-ui.sh | bash
```

Then:

1. Open **http://127.0.0.1:8091/**
2. Open **aws-terraform** and follow lessons from **Environment** onward.

Keep LocalStack running while you **Check**. The UI container talks to LocalStack at `host.docker.internal:4566`.

Work in a folder **outside** the course tree, e.g. `~/aws-labs/lesson-02/`.

---

## Typical lab flow

1. LocalStack healthy on `:4566`.
2. Write `.tf` files (hello world is one S3 bucket).
3. `terraform init` → `plan` → `apply` against LocalStack (`endpoints` / `skip_*` as in the first lab).
4. In the UI, **Check** (do not `destroy` before Check).
5. Later labs: IAM, S3 hardening, Lambda, DynamoDB, then the S3 → Lambda pipeline.

No paid AWS account. Do not omit `endpoints` or you may hit real AWS.

---

## Stop / reset

**Stop LocalStack (keep data volume):**

```bash
docker compose -f "$HOME/.mock-exams/localstack/docker-compose.yml" down
```

Windows:

```powershell
docker compose -f "$env:USERPROFILE\.mock-exams\localstack\docker-compose.yml" down
```

**Wipe LocalStack data:**

```bash
docker compose -f "$HOME/.mock-exams/localstack/docker-compose.yml" down -v
```

**Courses UI** (separate):

```bash
docker rm -f mockctl-web
```

---

## Troubleshooting

| Symptom | What to do |
|---------|------------|
| `irm : 404` | Confirm you are on `main` and the URL is `.../mockctl-setup/main/windows-localstack-up.ps1` |
| `License activation failed` / `LOCALSTACK_AUTH_TOKEN` | You pulled `localstack/localstack:latest`. This stack pins **3.8**. Delete the compose file under `.mock-exams/localstack/` and re-run the one-liner |
| `connection refused :4566` | Start Docker Desktop, re-run the one-liner |
| Port 4566 already in use | Stop the other LocalStack: `docker ps` then `docker compose … down` |
| `winget` finds no package | Exact id: `Hashicorp.Terraform` (not `HashiCorp.Terraform`). Or download the zip from the HashiCorp install page |
| Courses UI asks to enable Kubernetes | You used the **K8s** one-liner from [README.md](README.md). Use `windows-courses-ui.ps1` / `unix-courses-ui.sh` instead |
| Interactive Check cannot reach LocalStack | LocalStack must be up on the host (`:4566`). Re-run the LocalStack one-liner |
| Check fails after `destroy` | Check looks at LocalStack. Apply first, Check, then destroy |

---

## Files in this repo

| File | Purpose |
|------|---------|
| [`windows-localstack-up.ps1`](windows-localstack-up.ps1) | LocalStack (Windows) |
| [`unix-localstack-up.sh`](unix-localstack-up.sh) | LocalStack (macOS / Linux) |
| [`windows-courses-ui.ps1`](windows-courses-ui.ps1) | Courses UI, **no Kubernetes** (Windows) |
| [`unix-courses-ui.sh`](unix-courses-ui.sh) | Courses UI, **no Kubernetes** (macOS / Linux) |
| [`localstack/docker-compose.yml`](localstack/docker-compose.yml) | LocalStack 3.8 |

Kubernetes courses (different track): [README.md](README.md)  
GitLab CI/CD labs: [GITLAB.md](GITLAB.md)
