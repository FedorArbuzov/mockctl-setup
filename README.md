# mock-exams Windows bootstrap

Prerequisite: Docker Desktop running with Kubernetes enabled.

```powershell
irm https://raw.githubusercontent.com/FedorArbuzov/mock-exams-win/main/windows-mockctl-web.ps1 | iex
```

Then open http://127.0.0.1:8091/

## macOS / Linux

Prerequisite: Docker Desktop running with Kubernetes enabled.

```bash
curl -fsSL https://raw.githubusercontent.com/FedorArbuzov/mock-exams-win/main/unix-mockctl-web.sh | bash
```

Then open http://127.0.0.1:8091/
