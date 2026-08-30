# Courses UI only — no Kubernetes.
#
#   irm https://raw.githubusercontent.com/FedorArbuzov/mockctl-setup/main/windows-courses-ui.ps1 | iex
#
# Serves http://127.0.0.1:8091/  (lessons + Interactive Check for LocalStack labs).

param(
    [string] $Image = $(if ($env:MOCKCTL_WEB_IMAGE) { $env:MOCKCTL_WEB_IMAGE } else { "ghcr.io/fedorarbuzov/mock-exams/mockctl-web:latest" }),
    [int] $Port = $(if ($env:MOCKCTL_WEB_PORT) { [int]$env:MOCKCTL_WEB_PORT } else { 8091 })
)

$ErrorActionPreference = "Stop"

$Container = "mockctl-web"
$Url = "http://127.0.0.1:${Port}/"

Write-Host "Checking Docker..."
docker version --format "{{.Server.Version}}" | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Start Docker Desktop first." }

Write-Host "Pulling $Image ..."
$prev = $ErrorActionPreference
$ErrorActionPreference = "Continue"
docker pull $Image
$pullOk = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = $prev
if (-not $pullOk) {
    docker image inspect $Image | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Image not found: $Image" }
    Write-Host "Pull failed; using a local copy of $Image"
}

cmd.exe /c "docker rm -f $Container >nul 2>&1" | Out-Null
docker run -d `
    --name $Container `
    --restart unless-stopped `
    -p "${Port}:8091" `
    --add-host host.docker.internal:host-gateway `
    $Image
if ($LASTEXITCODE -ne 0) { throw "docker run failed" }

Write-Host "Waiting for courses UI on $Url ..."
$deadline = (Get-Date).AddMinutes(2)
$ready = $false
while ((Get-Date) -lt $deadline) {
    try {
        $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3
        if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) {
            $ready = $true
            break
        }
    } catch {
        # still starting
    }
    Write-Host "  still starting..."
    Start-Sleep -Seconds 2
}
if (-not $ready) {
    throw "Courses UI not up after 2 min. Check: docker logs $Container"
}

Write-Host ""
Write-Host "OK  $Url"
Write-Host "Stop: docker rm -f $Container"
