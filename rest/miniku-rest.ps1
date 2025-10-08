$ErrorActionPreference = "Stop"

$yamlDir = "..\k8s"
$clientDir = "..\wasm_game_client"
$servicesDir = "../services"

Write-Host "🔨 Compilando binários..." -ForegroundColor Cyan
.\build\build.ps1

try {
    Push-Location $servicesDir

    Write-Host "`n🐳 Construindo imagens Docker..." -ForegroundColor Cyan
    docker build -f servico_a/Dockerfile -t servico_a:latest .
    docker build -f servico_b/Dockerfile -t servico_b:latest .
    docker build -f gateway_p_go/Dockerfile -t gateway_go:latest .

    Pop-Location

    Write-Host "📥 Carregando imagens no Minikube..." -ForegroundColor Cyan
    minikube image load servico_a:latest
    minikube image load servico_b:latest
    minikube image load gateway_go:latest

    Push-Location $yamlDir

    Write-Host "🚢 Aplicando manifestos..." -ForegroundColor Cyan
    kubectl apply -f service_a_deployment.yaml
    kubectl apply -f service_b_deployment.yaml
    kubectl apply -f gateway_go_deployment.yaml

    Pop-Location

    Write-Host "⏳ Aguardando pods..." -ForegroundColor Cyan
    kubectl wait --for=condition=ready pod -l app=service-a --timeout=60s
    kubectl wait --for=condition=ready pod -l app=service-b --timeout=60s
    kubectl wait --for=condition=ready pod -l app=gateway-go --timeout=60s

    python3 -m http.server 8080 --directory "$clientDir\www" &
    Start-Sleep -Seconds 5

    Write-Host "🔌 Iniciando port-forward..." -ForegroundColor Cyan
    $portForwardProcess = Start-Process -FilePath "kubectl" -ArgumentList "port-forward service/gateway-go 8000:8000" -NoNewWindow -PassThru

    Write-Host "`n✅ Pronto! http://localhost:8000" -ForegroundColor Green
    Write-Host "Pressione Ctrl+C para encerrar`n" -ForegroundColor Yellow

    $portForwardProcess | Wait-Process
}
finally {
    if ($portForwardProcess -and -not $portForwardProcess.HasExited) {
        Stop-Process -Id $portForwardProcess.Id -Force
    }
}