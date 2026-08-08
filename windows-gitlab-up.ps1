# GitLab CE + runner in one shot (Docker Desktop / Docker Engine).
#
#   irm https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main/windows-gitlab-up.ps1 | iex
#
# First boot: 5–15 minutes. Needs ~4–6 GB RAM free for GitLab.

$ErrorActionPreference = "Stop"

$RepoRaw = "https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main"
$Dir = Join-Path (Join-Path $env:USERPROFILE ".mock-exams") "gitlab"
$Compose = Join-Path $Dir "docker-compose.yml"
$GitLab = "mock-gitlab"
$Runner = "mock-gitlab-runner"
$Url = "http://localhost:8929"

Write-Host "Checking Docker..."
docker info *> $null
if ($LASTEXITCODE -ne 0) { throw "Start Docker Desktop first." }

New-Item -ItemType Directory -Force -Path $Dir | Out-Null

Write-Host "Fetching compose -> $Compose"
try {
    Invoke-WebRequest -Uri "$RepoRaw/gitlab/docker-compose.yml" -OutFile $Compose -UseBasicParsing
} catch {
    throw "Could not download docker-compose.yml: $($_.Exception.Message)"
}

Write-Host "Starting GitLab stack (first pull can take a while)..."
docker compose -f $Compose up -d
if ($LASTEXITCODE -ne 0) { throw "docker compose up failed" }

Write-Host "Waiting for GitLab (puma + sidekiq). This can take 5–15 min on first boot..."
$deadline = (Get-Date).AddMinutes(20)
$ready = $false
while ((Get-Date) -lt $deadline) {
    $running = (docker inspect -f "{{.State.Running}}" $GitLab 2>$null)
    if ($running -ne "true") {
        Write-Host "  container not running yet..."
        Start-Sleep -Seconds 15
        continue
    }
    $status = docker exec $GitLab gitlab-ctl status 2>$null | Out-String
    if ($status -match "run: puma" -and $status -match "run: sidekiq") {
        $ready = $true
        break
    }
    Write-Host "  still starting..."
    Start-Sleep -Seconds 15
}
if (-not $ready) {
    throw "GitLab not ready after 20 min. Check: docker exec $GitLab gitlab-ctl status"
}

Write-Host "GitLab is up. Bootstrapping runner..."
$cfg = docker exec $Runner cat /etc/gitlab-runner/config.toml 2>$null | Out-String
if ($cfg -match "\[\[runners\]\]" -and $cfg -match "http://gitlab") {
    Write-Host "Runner already registered — skip."
} else {
    $token = docker exec $GitLab gitlab-rails runner "puts Gitlab::CurrentSettings.current_application_settings.runners_registration_token" 2>$null
    $token = ($token | Select-Object -Last 1).ToString().Trim()
    if (-not $token) { throw "Empty registration token. See README for manual runner register." }

    docker exec $Runner gitlab-runner register `
        --non-interactive `
        --url http://gitlab `
        --token $token `
        --executor docker `
        --docker-image alpine:latest `
        --description "local-docker" `
        --tag-list "docker,local" `
        --docker-network-mode host
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: auto-register failed. Register manually (see README)."
    } else {
        Write-Host "Registered runner tags: docker, local"
    }
}

Write-Host ""
Write-Host "OK  $Url"
Write-Host "Login: root"
Write-Host "Password (first boot only):"
Write-Host "  docker exec $GitLab grep 'Password:' /etc/gitlab/initial_root_password"
Write-Host "Stop (keep data): docker compose -f `"$Compose`" down"
Write-Host "Wipe data:        docker compose -f `"$Compose`" down -v"
