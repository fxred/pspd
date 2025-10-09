$ErrorActionPreference = "Stop"

$yamlDir = ".\k8s"
$clientDir = ".\wasm_game_client"

Write-Host "🔨 Compilando binários..." -ForegroundColor Cyan
.\build\build.ps1

try {
    Write-Host "`n🐳 Construindo imagens Docker..." -ForegroundColor Cyan
    docker build -f Dockerfile.a -t servico_a:latest .
    docker build -f Dockerfile.b -t servico_b:latest .
    docker build -f Dockerfile.gateway -t gateway_go:latest .

    Write-Host "📥 Carregando imagens no Minikube..." -ForegroundColor Cyan
    minikube image load servico_a:latest
    minikube image load servico_b:latest
    minikube image load gateway_go:latest

    Write-Host "🚢 Aplicando manifestos..." -ForegroundColor Cyan
    kubectl apply -f "$yamlDir\service_a_deployment.yaml"
    kubectl apply -f "$yamlDir\service_b_deployment.yaml"
    kubectl apply -f "$yamlDir\gateway_go_deployment.yaml"

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