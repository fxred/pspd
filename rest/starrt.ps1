# --- Configuração Inicial ---
$BASE_DIR = Get-Location
$LogDir = "$BASE_DIR\logs"
$TargetDir = "$BASE_DIR\target\release"

# --- Funções Auxiliares ---

# Executa um passo de compilação de forma robusta, lidando com cmdlets e executáveis externos.
function Invoke-BuildStep {
    param(
        [string]   $StepName,
        [string]   $Command,
        [hashtable]$Arguments,
        [switch]   $IgnoreErrors
    )
    
    Write-Host " 📦 $StepName..." -NoNewline
    
    if ($Arguments.ContainsKey('ArgumentList')) {
        & $Command @($Arguments['ArgumentList']) *> "$LogDir\build.log"
    } else {
        if ($IgnoreErrors) {
            $Arguments['ErrorAction'] = 'SilentlyContinue'
        }
        & $Command @Arguments *> "$LogDir\build.log"
    }

    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0 -and !$IgnoreErrors) {
        Write-Host " ❌ ERRO" -ForegroundColor Red
        Write-Host "      A etapa '$StepName' falhou. Verifique o log em '$LogDir\build.log'." -ForegroundColor Yellow
        exit 1
    }
    Write-Host " ✅" -ForegroundColor Green
}


function Start-Service($ServiceName, $FilePath, $ArgumentList, $WorkingDirectory) {
    $process = Start-Process -PassThru -NoNewWindow -FilePath $FilePath -ArgumentList $ArgumentList -WorkingDirectory $WorkingDirectory -RedirectStandardOutput "$LogDir\$($ServiceName).log" -RedirectStandardError "$LogDir\$($ServiceName).err"
    return $process.Id
}

# --- Script Principal ---

# 1. Preparação e Limpeza Prévia
Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
Write-Host "🧹 Etapa 0: Garantindo um ambiente limpo..." -ForegroundColor Cyan
Stop-Process -Name "servico_a", "servico_b" -Force -ErrorAction SilentlyContinue
if ($PID_GATEWAY) { Stop-Process -Id $PID_GATEWAY -Force -ErrorAction SilentlyContinue }
if ($PID_WASM) { Stop-Process -Id $PID_WASM -Force -ErrorAction SilentlyContinue }
Write-Host "✅ Ambiente limpo." -ForegroundColor Green


if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir }
Remove-Item -Path "$LogDir\*" -Include *.log, *.err -ErrorAction SilentlyContinue

Write-Host "`n🚀 Etapa 1: Construindo todos os projetos..." -ForegroundColor Yellow

# 2. Compilação
Invoke-BuildStep "Limpando builds antigos" "Remove-Item" @{ Path = "$BASE_DIR\wasm_game_client\www\pkg"; Recurse = $true; Force = $true } -IgnoreErrors
Invoke-BuildStep "Construindo WASM Client" "cargo" @{ ArgumentList = @("build", "--target", "wasm32-unknown-unknown", "--release", "--package", "wasm_game_client") }
Invoke-BuildStep "Executando wasm-bindgen" "wasm-bindgen" @{ ArgumentList = @("--out-dir", "$BASE_DIR\wasm_game_client\www\pkg", "--target", "web", "$BASE_DIR\target\wasm32-unknown-unknown\release\wasm_game_client.wasm") }
Invoke-BuildStep "Construindo Serviço A" "cargo" @{ ArgumentList = @("build", "--release", "--package", "servico_a") }
Invoke-BuildStep "Construindo Serviço B" "cargo" @{ ArgumentList = @("build", "--release", "--package", "servico_b") }

Push-Location "$BASE_DIR\gateway_p_go"
Invoke-BuildStep "Construindo Gateway P (GO)" "go" @{ ArgumentList = @("build", "-o", "$TargetDir\gateway_go.exe", ".") }
Pop-Location

# 3. Inicialização
Write-Host "`n🚀 Etapa 2: Iniciando todos os serviços..." -ForegroundColor Yellow
$PID_A = Start-Service "servico_a" "$TargetDir\servico_a.exe" @() "$BASE_DIR"
$PID_B = Start-Service "servico_b" "$TargetDir\servico_b.exe" @() "$BASE_DIR"
$PID_GATEWAY = Start-Service "gateway_go" "$TargetDir\gateway_go.exe" @() "$BASE_DIR"
$PID_WASM = Start-Service "client_wasm" "python3" @("-m", "http.server", "8080") "$BASE_DIR\wasm_game_client\www"

Start-Sleep -Seconds 2

# 4. Loop Interativo e Limpeza
Write-Host "`n--------------------------------------------------" -ForegroundColor DarkGray
Write-Host "✅ Todos os serviços foram iniciados!" -ForegroundColor Green
Write-Host "   - Cliente web disponível em http://localhost:8080"
Write-Host "   - PIDs: A=$PID_A, B=$PID_B, Gateway=$PID_GATEWAY, WASM=$PID_WASM"
Write-Host "--------------------------------------------------`n" -ForegroundColor DarkGray
Write-Host "Pressione 'r' para resetar o serviço B, 'q' para sair." -ForegroundColor Yellow

function Reset-ServiceB {
    Write-Host "`n🔄 Resetando serviço B..." -ForegroundColor Cyan
    Stop-Process -Id $script:PID_B -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    $script:PID_B = Start-Service "servico_b" "$TargetDir\servico_b.exe" @() "$BASE_DIR"
    Write-Host "✅ Serviço B reiniciado. Novo PID: $($script:PID_B)" -ForegroundColor Green
}

function Cleanup {
    Write-Host "`n🛑 Encerrando todos os serviços..." -ForegroundColor Red
    Stop-Process -Id $PID_A, $PID_B, $PID_GATEWAY, $PID_WASM -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Serviços encerrados." -ForegroundColor Green
    exit
}

try {
    while ($true) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true).KeyChar
            if ($key -eq 'r') { Reset-ServiceB }
            elseif ($key -eq 'q') { Cleanup }
        }
        Start-Sleep -Milliseconds 100
    }
}
finally {
    Cleanup
}