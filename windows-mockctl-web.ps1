# Docker Desktop K8s + mockctl-web in one shot.
#
#   irm https://raw.githubusercontent.com/FedorArbuzov/mock-exams-win/main/windows-mockctl-web.ps1 | iex
#
# Before running: Docker Desktop -> Settings -> Kubernetes -> Create cluster.

param(
    [string] $Image = $(if ($env:MOCKCTL_WEB_IMAGE) { $env:MOCKCTL_WEB_IMAGE } else { "ghcr.io/fedorarbuzov/mock-exams/mockctl-web:latest" }),
    [int] $Port = $(if ($env:MOCKCTL_WEB_PORT) { [int]$env:MOCKCTL_WEB_PORT } else { 8091 })
)

$ErrorActionPreference = "Stop"

$Kubeconfig = Join-Path (Join-Path $env:USERPROFILE ".mock-exams") "kubeconfig.yaml"
$Container = "mockctl-web"

# 1. Docker up?
docker info *> $null
if ($LASTEXITCODE -ne 0) { throw "Start Docker Desktop first." }

# 2. K8s ready?
$ctx = kubectl config get-contexts -o name 2>$null
if ($ctx -notcontains "docker-desktop") {
    throw "Enable Kubernetes in Docker Desktop (Settings -> Kubernetes -> Create cluster)."
}
kubectl config use-context docker-desktop | Out-Null
kubectl get nodes
if ($LASTEXITCODE -ne 0) { throw "Cluster not ready yet. Wait a minute and retry." }

# 3. Save kubeconfig for the container
New-Item -ItemType Directory -Force -Path (Split-Path $Kubeconfig) | Out-Null
kubectl config view --minify --flatten --context=docker-desktop | Set-Content $Kubeconfig -Encoding utf8

# 4. Pull image (skip if already local)
$prev = $ErrorActionPreference
$ErrorActionPreference = "Continue"
docker pull $Image *> $null
$pullOk = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = $prev
if (-not $pullOk) {
    docker image inspect $Image *> $null
    if ($LASTEXITCODE -ne 0) { throw "Image not found: $Image" }
}

# 5. Run (cmd swallows "No such container" — PowerShell treats docker stderr as errors)
cmd.exe /c "docker rm -f $Container >nul 2>&1" | Out-Null
docker run -d `
    --name $Container `
    --restart unless-stopped `
    -p "${Port}:8091" `
    -v "${Kubeconfig}:/kube/host-kubeconfig.yaml:ro" `
    --add-host host.docker.internal:host-gateway `
    $Image

# 6. Quick check
Start-Sleep -Seconds 2
docker exec $Container kubectl --kubeconfig=/work/output/kubeconfig.yaml get nodes
if ($LASTEXITCODE -ne 0) { throw "Container cannot reach the cluster. docker logs $Container" }

Write-Host ""
Write-Host "OK  http://127.0.0.1:${Port}/"
Write-Host "Stop: docker rm -f $Container"
