$ErrorActionPreference = "Stop"

function Cleanup {
    Write-Host "`nEncerrando o script e parando o port-forward..." -ForegroundColor Yellow
    Get-Process | Where-Object { $_.ProcessName -eq "kubectl" -and $_.CommandLine -like "*port-forward*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    exit 0
}

Register-EngineEvent PowerShell.Exiting -Action { Cleanup }
$null = Register-ObjectEvent -InputObject ([Console]) -EventName CancelKeyPress -Action { Cleanup }


if (!(Get-Command minikube -ErrorAction SilentlyContinue)) {
    Write-Error "Erro: minikube não está instalado"
}

try {
    $status = minikube status 2>$null
    if ($status -match "host: Running") {
        Write-Host "Parando minikube..." -ForegroundColor Yellow
        minikube stop
    } else {
        Write-Host "Minikube não está rodando" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Minikube não está rodando" -ForegroundColor Yellow
}

Write-Host "ATENÇÃO: Isso irá deletar TODOS os clusters minikube existentes!" -ForegroundColor Red
$reply = Read-Host "Deseja continuar? (y/N)"
if ($reply -notmatch "^[Yy]$") {
    Write-Host "Operação cancelada" -ForegroundColor Yellow
    exit 0
}

Write-Host "♻️  Reiniciando o Minikube..." -ForegroundColor Cyan

minikube delete --all
minikube start

Write-Host "🛠️  Construindo imagens Docker..." -ForegroundColor Cyan
docker build -f gateway_p/Dockerfile -t ruby-gateway:latest .
docker build -f service_a/Dockerfile -t service-a:latest .
docker build -f service_b/Dockerfile -t service-b:latest .

Write-Host "🚢 Aplicando manifestos Kubernetes..." -ForegroundColor Cyan
kubectl apply -f ruby-gateway.yaml
kubectl apply -f service-a.yaml
kubectl apply -f service-b.yaml

Write-Host "📥 Carregando imagens no Minikube..." -ForegroundColor Cyan
minikube image load service-a:latest
minikube image load service-b:latest
minikube image load ruby-gateway:latest

$pods = @("ruby-gateway", "service-a", "service-b")
foreach ($pod in $pods) {
    Write-Host "Aguardando o pod '$pod' ficar pronto..."
    kubectl wait --for=condition=Ready pod -l app=$pod --timeout=120s
    Write-Host "O pod '$pod' está pronto."
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Erro: O pod '$pod' não ficou pronto a tempo."
    }
}

Write-Host "🔌 Iniciando port-forward em segundo plano..." -ForegroundColor Cyan
$portForwardProcess = Start-Process -FilePath "kubectl" -ArgumentList "port-forward service/ruby-gateway-service 8082:8082" -NoNewWindow -PassThru


Write-Host "`n🚀 Script concluído! O port-forward para 'ruby_gateway' está ativo." -ForegroundColor Green
Write-Host "Pressione [Ctrl+C] para encerrar este script e o port-forward."

$portForwardProcess | Wait-Process