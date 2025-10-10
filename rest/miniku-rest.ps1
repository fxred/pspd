$ErrorActionPreference = "Stop"

function Cleanup {
    Write-Host "`nEncerrando o script e parando o port-forward..." -ForegroundColor Yellow
    Get-Process | Where-Object { $_.ProcessName -eq "kubectl" -and $_.CommandLine -like "*port-forward*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    exit 0
}

Register-EngineEvent PowerShell.Exiting -Action { Cleanup }
$null = Register-ObjectEvent -InputObject ([Console]) -EventName CancelKeyPress -Action { Cleanup }

$YAML_DIR = "./k8s"

Write-Host "Compilando binários..." -ForegroundColor Green
"./build.ps1"


Write-Host "`n🐳 Construindo imagens Docker..." -ForegroundColor Cyan
docker build -f Dockerfile.a -t servico_a:latest .
docker build -f Dockerfile.b -t servico_b:latest .
docker build -f Dockerfile.gateway -t gateway_go:latest .

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

minikube delete --all
minikube start

Push-Location $YAML_DIR

Write-Host "Carregando imagens no Minikube..." -ForegroundColor Green
minikube image load servico_a:latest
minikube image load servico_b:latest
minikube image load gateway_go:latest

Write-Host "Aplicando manifestos Kubernetes..." -ForegroundColor Green
kubectl apply -f gateway_go_deployment.yaml
kubectl apply -f service_a_deployment.yaml
kubectl apply -f service_b_deployment.yaml

Write-Host "🔌 Iniciando port-forward em segundo plano..." -ForegroundColor Green
Start-Sleep 10

$job = Start-Job -ScriptBlock {
    kubectl port-forward service/gateway-go 8000:8000
}

Write-Host "`nScript concluído! O port-forward para 'gateway-go' está ativo." -ForegroundColor Green
Write-Host "Pressione [Ctrl+C] para encerrar este script e o port-forward." -ForegroundColor Cyan

try {
    Wait-Job $job
} finally {
    Stop-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -ErrorAction SilentlyContinue
    Pop-Location
}