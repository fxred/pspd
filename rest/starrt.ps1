$BASE_DIR = Get-Location

$ProcessA = Start-Process -PassThru -NoNewWindow -FilePath "cargo" -ArgumentList "run", "--release" -WorkingDirectory "$BASE_DIR\servico_a"
Start-Sleep -Milliseconds 500
$PID_A = $ProcessA.Id

$ProcessB = Start-Process -PassThru -NoNewWindow -FilePath "cargo" -ArgumentList "run", "--release" -WorkingDirectory "$BASE_DIR\servico_b"
Start-Sleep -Milliseconds 500
$PID_B = $ProcessB.Id

$ProcessP = Start-Process -PassThru -NoNewWindow -FilePath "go" -ArgumentList "run", "main.go" -WorkingDirectory "$BASE_DIR\gateway_p_go"
Start-Sleep -Milliseconds 500
$PID_GATEWAY = $ProcessP.Id

$ProcessWebClient = Start-Process -PassThru -NoNewWindow -FilePath "powershell" -ArgumentList "-File", ".\rezzet.ps1" -WorkingDirectory "$BASE_DIR\wasm_game_client"
Start-Sleep -Milliseconds 500
$PID_WASM = $ProcessWebClient.Id

Write-Host "Serviços iniciados." -ForegroundColor Green
Write-Host "Comandos: 'r' para resetar serviço B, 'q' para sair" -ForegroundColor Yellow

function Reset-ServiceB {
    Write-Host "Resetando serviço B..." -ForegroundColor Cyan
    Stop-Process -Id $script:PID_B -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    
    Start-Process -NoNewWindow -FilePath "cargo" -ArgumentList "run", "--release" -WorkingDirectory "$BASE_DIR\servico_b"
    Start-Sleep -Milliseconds 500
    $script:PID_B = (Get-Process cargo | Where-Object {$_.Path -like "*servico_b*"} | Select-Object -First 1).Id
    Write-Host "Serviço B reiniciado. Novo PID: $($script:PID_B)" -ForegroundColor Green
}

function Cleanup {
    Write-Host "`nEncerrando serviços..." -ForegroundColor Red
    Stop-Process -Id $PID_A -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $PID_B -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $PID_GATEWAY -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $PID_WASM -Force -ErrorAction SilentlyContinue
    exit
}

try {
    while ($true) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true).KeyChar
            if ($key -eq 'r') {
                Reset-ServiceB
            }
            elseif ($key -eq 'q') {
                Cleanup
            }
        }
        Start-Sleep -Milliseconds 100
    }
}
finally {
    Cleanup
}