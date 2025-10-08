$ErrorActionPreference = "Stop"

$yamlDir = "..\k8s-rest"

try {
    Write-Host "♻️  Reiniciando o Minikube..." -ForegroundColor Cyan
    minikube stop
    minikube delete --all
    minikube start

    Write-Host "🛠️  Construindo imagens Docker..." -ForegroundColor Cyan
    docker build -f gateway_p_go/Dockerfile -t gateway_go:latest .
    docker build -f servico_a/Dockerfile -t servico_a:latest .
    docker build -f servico_b/Dockerfile -t servico_b:latest .
    #docker build -f wasm_game_client/Dockerfile -t wasm_client_rest:latest .

    Push-Location $yamlDir

    Write-Host "📥 Carregando imagens no Minikube..." -ForegroundColor Cyan
    minikube image load servico_a:latest
    minikube image load servico_b:latest
    minikube image load gateway_go:latest
    #minikube image load wasm_client_rest:latest
    
    Write-Host "🚢 Aplicando manifestos Kubernetes..." -ForegroundColor Cyan
    kubectl apply -f gateway_go_deployment.yaml
    kubectl apply -f service_a_deployment.yaml
    kubectl apply -f service_b_deployment.yaml
    #kubectl apply -f wasm_client_deployment.yaml

    Start-Sleep -Seconds 10

    Write-Host "🔌 Iniciando port-forward em segundo plano..." -ForegroundColor Cyan
    $portForwardProcess = Start-Process -FilePath "kubectl" -ArgumentList "port-forward service/gateway-go 8000:8000" -NoNewWindow -PassThru


    #Write-Host "🌐 Obtendo URL do serviço wasm-client-rest..." -ForegroundColor Cyan
    #minikube service wasm-client-rest --url

    Write-Host "`n🚀 Script concluído! O port-forward para 'gateway-go' está ativo." -ForegroundColor Green
    Write-Host "Pressione [Ctrl+C] para encerrar este script e o port-forward."

    $portForwardProcess | Wait-Process
}
finally {
    Write-Host "`nEncerrando o script e parando o port-forward..." -ForegroundColor Yellow
    if ($portForwardProcess -and -not $portForwardProcess.HasExited) {
        Stop-Process -Id $portForwardProcess.Id -Force
    }
    Pop-Location
}