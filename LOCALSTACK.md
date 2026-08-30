# AWS + Terraform labs — local setup

How to run the **aws-terraform** course without Kubernetes, minikube, or a real AWS account.

You need **Docker Desktop** (or Docker Engine). One command starts:

- **LocalStack** on **http://localhost:4566**
- **`lab`** — Terraform + AWS CLI, files in **`~/aws-labs`**
- **courses UI** on **http://127.0.0.1:8091/aws-terraform/README.md**

Interactive Check uses AWS CLI **inside the UI container** against LocalStack (`http://localstack:4566`). No Terraform or AWS CLI on the host is required (`exec lab bash`).

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

1. Writes compose to `~/.mock-exams/localstack/` (Windows: `%USERPROFILE%\.mock-exams\localstack\`)
2. Creates `~/aws-labs`
3. Pulls LocalStack, `aws-terraform-lab`, and `mockctl-web`
4. Starts all three containers
5. Waits until LocalStack health and the courses UI respond

Expected last lines:

```text
OK  course:     http://127.0.0.1:8091/aws-terraform/README.md
    LocalStack  http://localhost:4566
    workdir:    .../aws-labs
    lab:        docker compose -f ... exec lab bash
```

Open the course URL. Terraform in the toolbox:

```bash
docker compose -f ~/.mock-exams/localstack/docker-compose.yml exec lab bash
```

PowerShell:

```powershell
docker compose -f "$env:USERPROFILE\.mock-exams\localstack\docker-compose.yml" exec lab bash
```

Inside `lab`, `localhost:4566` is LocalStack (same URLs as in the course). You are in `/aws-labs`.

**Port 4566** — only one LocalStack at a time.  
**Port 8091** — the script removes a leftover `mockctl-web` if it is occupying the UI port.

Do **not** use the [main README](README.md) one-liner — that path needs Kubernetes.

---

## Optional: tools on the host

If you prefer `terraform` / `aws` on the laptop instead of `lab`: [Install Terraform](https://developer.hashicorp.com/terraform/install), [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html). Fake keys: `test` / `test` / `us-east-1`.

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
| lab or web image **denied** / 401 | Make the GHCR package **Public**: [aws-terraform-lab](https://github.com/FedorArbuzov/mock-exams/pkgs/container/mock-exams%2Faws-terraform-lab), [mockctl-web](https://github.com/FedorArbuzov/mock-exams/pkgs/container/mock-exams%2Fmockctl-web) — Package settings → Danger Zone → Change visibility |
| `License activation failed` | Pin is **3.8**, not `latest`. Delete `~/.mock-exams/localstack/` and re-run |
| Port 4566 in use | Stop the other LocalStack (`docker ps`, then `compose down`) |
| Port 8091 in use | Re-run the one-liner (it removes leftover `mockctl-web`) |
| Courses UI asks for Kubernetes | You used the **K8s** one-liner. Use this LocalStack script instead |

Course details: [aws-terraform ENVIRONMENT](https://github.com/FedorArbuzov/mock-exams/blob/master/courses-en/aws-terraform/ENVIRONMENT.md) (after that file is on `master`).
