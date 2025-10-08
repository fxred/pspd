$env:SERVICE_A_URL = "http://localhost:3002"
$env:SERVICE_B_URL = "http://localhost:3001"

Write-Host "🚀 Iniciando serviços..." -ForegroundColor Cyan
Write-Host "   - SERVICE_A_URL: $env:SERVICE_A_URL"
Write-Host "   - SERVICE_B_URL: $env:SERVICE_B_URL"
Write-Host ""

try {
    $svc_a = Start-Process -PassThru -FilePath ".\servico_a.exe"
    $svc_b = Start-Process -PassThru -FilePath ".\servico_b.exe"
    $svc_g = Start-Process -PassThru -FilePath ".\gateway_go.exe"
    $clnt  = Start-Process -PassThru -FilePath "python3" -ArgumentList "-m http.server 8080 --directory `"$PSScriptRoot\www`""

    Write-Host "✅ Serviços iniciados em background." -ForegroundColor Green
    Write-Host "🎮 Acesse: http://localhost:8080" -ForegroundColor Green
    Write-Host "👉 Pressione [Ctrl+C] para encerrar." -ForegroundColor Yellow

    while ($true) {
        Start-Sleep -Seconds 1
    }

}
finally {
    Write-Host "`n🛑 Encerrando os serviços..." -ForegroundColor Red
    Stop-Process -Id $svc_a.Id -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $svc_b.Id -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $svc_g.Id -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $clnt.Id -Force -ErrorAction SilentlyContinue
    
    Remove-Item Env:\SERVICE_A_URL
    Remove-Item Env:\SERVICE_B_URL
}