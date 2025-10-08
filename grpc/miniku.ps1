$ErrorActionPreference = "Stop"

try {
    Write-Host "♻️  Reiniciando o Minikube..." -ForegroundColor Cyan
    minikube stop
    minikube delete --all
    minikube start

    Write-Host "🛠️  Construindo imagens Docker..." -ForegroundColor Cyan
    docker build -f gateway_p/Dockerfile -t ruby-gateway:latest .
    docker build -f service_a/Dockerfile -t service-a:latest .
    docker build -f service_b/Dockerfile -t service-b:latest .
    docker build -f wasm_game_client/Dockerfile -t wasm-client:latest .

    Write-Host "🚢 Aplicando manifestos Kubernetes..." -ForegroundColor Cyan
    kubectl apply -f ruby-gateway.yaml
    kubectl apply -f service-a.yaml
    kubectl apply -f service-b.yaml
    kubectl apply -f wasm-client.yaml

    Write-Host "📥 Carregando imagens no Minikube..." -ForegroundColor Cyan
    minikube image load service-a:latest
    minikube image load service-b:latest
    minikube image load ruby-gateway:latest
    minikube image load wasm-client:latest

    Write-Host "🔌 Iniciando port-forward em segundo plano..." -ForegroundColor Cyan
    $portForwardProcess = Start-Process -FilePath "kubectl" -ArgumentList "port-forward service/ruby-gateway-service 8082:8082" -NoNewWindow -PassThru

    Start-Sleep -Seconds 3

    Write-Host "🌐 Obtendo URL do serviço wasm-client..." -ForegroundColor Cyan
    minikube service wasm-client-service --url

    Write-Host "`n🚀 Script concluído! O port-forward para 'ruby_gateway' está ativo." -ForegroundColor Green
    Write-Host "Pressione [Ctrl+C] para encerrar este script e o port-forward."

    $portForwardProcess | Wait-Process
}
finally {
    Write-Host "`nEncerrando o script e parando o port-forward..." -ForegroundColor Yellow
    if ($portForwardProcess -and -not $portForwardProcess.HasExited) {
        Stop-Process -Id $portForwardProcess.Id -Force
    }
    if ((Get-Location).Path -ne $PWD.Path) {
        Pop-Location
    }
}