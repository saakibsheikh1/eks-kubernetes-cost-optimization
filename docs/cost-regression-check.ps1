param(
    [string]$Namespace = "cost-baseline",
    [string]$Deployment = "cost-baseline-app",
    [int]$ExpectedCpuRequestMillicores = 50,
    [int]$ThresholdCpuRequestMillicores = 75
)

Write-Host "Kubernetes Cost Regression Check"
Write-Host "================================"
Write-Host "Namespace : $Namespace"
Write-Host "Deployment: $Deployment"
Write-Host ""

$deploymentJson = kubectl get deployment $Deployment `
    -n $Namespace `
    -o json | ConvertFrom-Json

if (-not $deploymentJson) {
    Write-Host "ERROR: Deployment not found."
    exit 2
}

$containers = $deploymentJson.spec.template.spec.containers

$totalReplicas = [int]$deploymentJson.spec.replicas
$totalCpuRequest = 0

foreach ($container in $containers) {
    $request = $container.resources.requests.cpu

    if (-not $request) {
        Write-Host "ALERT: Container '$($container.name)' has no CPU request."
        exit 1
    }

    if ($request -match '^([0-9]+)m$') {
        $cpuMillicores = [int]$Matches[1]
    }
    elseif ($request -match '^([0-9]+(?:\.[0-9]+)?)$') {
        $cpuMillicores = [int]([double]$request * 1000)
    }
    else {
        Write-Host "ERROR: Unsupported CPU request format: $request"
        exit 2
    }

    $totalCpuRequest += $cpuMillicores
}

$perPodCpuRequest = [int]($totalCpuRequest / $containers.Count)
$totalRequestedCpu = $perPodCpuRequest * $totalReplicas

Write-Host "Expected CPU request per pod : ${ExpectedCpuRequestMillicores}m"
Write-Host "Current CPU request per pod  : ${perPodCpuRequest}m"
Write-Host "Current replicas              : $totalReplicas"
Write-Host "Total requested CPU           : ${totalRequestedCpu}m"
Write-Host ""

if ($perPodCpuRequest -gt $ThresholdCpuRequestMillicores) {
    Write-Host "ALERT: CPU request regression detected!"
    Write-Host "Current request ${perPodCpuRequest}m exceeds threshold ${ThresholdCpuRequestMillicores}m."
    Write-Host "This can reduce bin-packing efficiency and increase node cost."
    exit 1
}

if ($perPodCpuRequest -gt $ExpectedCpuRequestMillicores) {
    Write-Host "WARNING: CPU request is above the optimized baseline."
    Write-Host "Current request ${perPodCpuRequest}m."
    Write-Host "Expected optimized request ${ExpectedCpuRequestMillicores}m."
    exit 1
}

Write-Host "PASS: CPU request is within the optimized cost baseline."
exit 0