# LocalStack in one shot (Docker Desktop / Docker Engine). No Kubernetes.
#
#   irm https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main/windows-localstack-up.ps1 | iex
#
# Endpoint: http://localhost:4566

$ErrorActionPreference = "Stop"

$RepoRaw = "https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main"
$Dir = Join-Path (Join-Path $env:USERPROFILE ".mock-exams") "localstack"
$Compose = Join-Path $Dir "docker-compose.yml"
$Container = "localstack-localstack-1"
$Url = "http://localhost:4566"

function Resolve-LocalCompose {
    if (-not $PSScriptRoot) { return $null }
    $candidates = @(
        (Join-Path $PSScriptRoot "localstack\docker-compose.yml"),
        (Join-Path $PSScriptRoot "..\deploy\localstack\docker-compose.yml")
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
    Invoke-WebRequest -Uri "$RepoRaw/localstack/docker-compose.yml" -OutFile $Compose -UseBasicParsing
}

function Get-ContainerState {
    $id = docker inspect -f "{{.State.Running}} {{.State.ExitCode}}" $Container 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return $id.Trim()
}

Write-Host "Checking Docker..."
docker info *> $null
if ($LASTEXITCODE -ne 0) { throw "Start Docker Desktop first." }

Install-ComposeFile

# Replace a leftover container with the same name (e.g. a previous docker run).
cmd.exe /c "docker rm -f $Container >nul 2>&1" | Out-Null

Write-Host "Starting LocalStack..."
docker compose -f $Compose up -d
if ($LASTEXITCODE -ne 0) { throw "docker compose up failed" }

Write-Host "Waiting for LocalStack health on $Url ..."
$deadline = (Get-Date).AddMinutes(5)
$ready = $false
while ((Get-Date) -lt $deadline) {
    $state = Get-ContainerState
    if ($state -and $state -notmatch "^true ") {
        $logs = docker compose -f $Compose logs --tail 40 2>$null | Out-String
        throw "LocalStack exited ($state). If logs mention a license / AUTH_TOKEN, pin localstack/localstack:3.8 (latest needs a token).`n$logs"
    }
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
    throw "LocalStack not healthy after 5 min. Check: docker compose -f `"$Compose`" logs"
}

Write-Host ""
Write-Host "OK  LocalStack  $Url"
Write-Host "    health:     $Url/_localstack/health"
Write-Host "    stop:       docker compose -f `"$Compose`" down"
Write-Host "    (data volume is kept; add -v to wipe)"
