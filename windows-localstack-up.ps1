# LocalStack + aws-terraform lab (Terraform, AWS CLI) in one shot. No Kubernetes.
#
# From this repo:
#   .\scripts\windows-localstack-up.ps1
#
# Public:
#   irm https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main/windows-localstack-up.ps1 | iex
#
# LocalStack: http://localhost:4566
# Course:     http://127.0.0.1:8091/aws-terraform/README.md
# Lab:        docker compose -f $env:USERPROFILE\.mock-exams\localstack\docker-compose.yml exec lab bash
# Workdir:    ~\aws-labs

$ErrorActionPreference = "Stop"

$RepoRaw = if ($env:MOCKCTL_SETUP_RAW) { $env:MOCKCTL_SETUP_RAW } else { "https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main" }
$ExamsRaw = if ($env:MOCK_EXAMS_RAW) { $env:MOCK_EXAMS_RAW } else { "https://raw.githubusercontent.com/FedorArbuzov/mock-exams/master" }
$Dir = Join-Path (Join-Path $env:USERPROFILE ".mock-exams") "localstack"
$Compose = Join-Path $Dir "docker-compose.yml"
$Url = "http://localhost:4566"
$Labs = Join-Path $env:USERPROFILE "aws-labs"

function Resolve-LocalCompose {
    if (-not $PSScriptRoot) { return $null }
    $candidates = @(
        (Join-Path $PSScriptRoot "..\deploy\aws-terraform\docker-compose.yml"),
        (Join-Path $PSScriptRoot "localstack\docker-compose.yml")
    )
    foreach ($c in $candidates) {
        $full = [IO.Path]::GetFullPath($c)
        if (Test-Path -LiteralPath $full) { return $full }
    }
    return $null
}

function Install-ComposeFile {
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    $local = Resolve-LocalCompose
    if ($local) {
        Write-Host "Using local compose $local"
        Copy-Item -LiteralPath $local -Destination $Compose -Force
        return
    }
    Write-Host "Fetching compose -> $Compose"
    $urls = @(
        "$RepoRaw/localstack/docker-compose.yml",
        "$ExamsRaw/deploy/aws-terraform/docker-compose.yml"
    )
    $ok = $false
    foreach ($u in $urls) {
        try {
            Invoke-WebRequest -Uri $u -OutFile $Compose -UseBasicParsing
            $ok = $true
            break
        } catch {
            # try next
        }
    }
    if (-not $ok) {
        throw "Could not get docker-compose.yml. Run from the mock-exams repo: .\scripts\windows-localstack-up.ps1"
    }
}

$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    throw "docker is not on PATH. Install Docker Desktop, then open a new PowerShell."
}
Write-Host "Checking Docker (up to 20s)..."
$out = Join-Path $env:TEMP "mock-docker-info.out"
$err = Join-Path $env:TEMP "mock-docker-info.err"
$p = Start-Process -FilePath $dockerCmd.Source -ArgumentList "version","--format","{{.Server.Version}}" -NoNewWindow -PassThru `
    -RedirectStandardOutput $out -RedirectStandardError $err
if (-not $p.WaitForExit(20000)) {
    try { $p.Kill() } catch { }
    throw "Docker is not responding. Start Docker Desktop and wait until the whale is steady (Running), then retry."
}
if ($p.ExitCode -ne 0) {
    throw "Start Docker Desktop first (engine is not running)."
}

Install-ComposeFile
New-Item -ItemType Directory -Force -Path $Labs | Out-Null

cmd.exe /c "docker rm -f localstack-localstack-1 mockctl-web mock-aws-terraform-localstack mock-aws-terraform-lab mock-aws-terraform-web >nul 2>&1" | Out-Null

Write-Host "Pulling images (LocalStack + lab + courses UI)..."
docker compose -f $Compose pull
if ($LASTEXITCODE -ne 0) {
    throw "Image pull failed. If a GHCR image is 401/denied, make that package Public."
}

Write-Host "Starting LocalStack + lab + courses UI..."
docker compose -f $Compose up -d
if ($LASTEXITCODE -ne 0) { throw "docker compose up failed" }

Write-Host "Waiting for LocalStack health on $Url ..."
$deadline = (Get-Date).AddMinutes(5)
$ready = $false
while ((Get-Date) -lt $deadline) {
    try {
        $r = Invoke-WebRequest -Uri "$Url/_localstack/health" -UseBasicParsing -TimeoutSec 3
        if ($r.StatusCode -eq 200) {
            $ready = $true
            break
        }
    } catch {
        # still starting
    }
    Write-Host "  still starting..."
    Start-Sleep -Seconds 3
}
if (-not $ready) {
    $logs = docker compose -f $Compose logs --tail 40 2>$null | Out-String
    throw "LocalStack not healthy after 5 min.`n$logs"
}

$labRunning = docker inspect -f "{{.State.Running}}" mock-aws-terraform-lab 2>$null
if ($LASTEXITCODE -ne 0 -or $labRunning -ne "true") {
    $logs = docker compose -f $Compose logs --tail 40 lab 2>$null | Out-String
    throw "Lab container is not running.`n$logs"
}

$Course = "http://127.0.0.1:8091/aws-terraform/README.md"
Write-Host "Waiting for courses UI on http://127.0.0.1:8091/ ..."
$uiDeadline = (Get-Date).AddMinutes(2)
$uiReady = $false
while ((Get-Date) -lt $uiDeadline) {
    try {
        $ui = Invoke-WebRequest -Uri "http://127.0.0.1:8091/" -UseBasicParsing -TimeoutSec 3
        if ($ui.StatusCode -ge 200 -and $ui.StatusCode -lt 500) {
            $uiReady = $true
            break
        }
    } catch {
        # still starting
    }
    Write-Host "  still starting..."
    Start-Sleep -Seconds 2
}
if (-not $uiReady) {
    $logs = docker compose -f $Compose logs --tail 40 web 2>$null | Out-String
    throw "Courses UI not up after 2 min.`n$logs"
}

Write-Host ""
Write-Host "OK  course:     $Course"
Write-Host "    LocalStack  $Url"
Write-Host "    health:     $Url/_localstack/health"
Write-Host "    workdir:    $Labs"
Write-Host "    lab:        docker compose -f `"$Compose`" exec lab bash"
Write-Host "    terraform:  docker compose -f `"$Compose`" exec lab terraform version"
Write-Host "    stop:       docker compose -f `"$Compose`" down"
Write-Host "    (LocalStack data volume is kept; add -v to wipe)"
