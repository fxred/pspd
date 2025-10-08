$ErrorActionPreference = "Stop"

Write-Host "🔨 BUILD WINDOWS - REST" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

$distBase = "./dist"
$windowsDir = "$distBase\windows"
$linuxDir = "$distBase\linux"
$servicesDir = "./services"

New-Item -ItemType Directory -Force -Path $windowsDir | Out-Null

# ============ RUST - Serviços A e B ============

Write-Host "🦀 Compilando Serviços Rust..." -ForegroundColor Yellow

rustup target add x86_64-pc-windows-msvc 2>$null
rustup target add wasm32-unknown-unknown 2>$null

Write-Host "  📦 Windows..." -ForegroundColor Gray

cargo build --release --target x86_64-pc-windows-msvc -p servico_a
cargo build --release --target x86_64-pc-windows-msvc -p servico_b

Copy-Item "target\x86_64-pc-windows-msvc\release\servico_a.exe" "$windowsDir\servico_a.exe"
Copy-Item "target\x86_64-pc-windows-msvc\release\servico_b.exe" "$windowsDir\servico_b.exe"


# ============ WASM Client ============


Write-Host "`n🕸️  Compilando WASM Client..." -ForegroundColor Yellow

Remove-Item -Recurse -Force "wasm_game_client\www\pkg" -ErrorAction SilentlyContinue

Write-Host "  📦 WASM..." -ForegroundColor Gray
cargo build --release --target wasm32-unknown-unknown -p wasm_game_client

Write-Host "  🔗 Gerando bindings JS..." -ForegroundColor Gray
wasm-bindgen --out-dir "wasm_game_client\www\pkg" --target web "target\wasm32-unknown-unknown\release\wasm_game_client.wasm"

Write-Host "  📦 Copiando arquivos WASM..." -ForegroundColor Gray
Copy-Item -Recurse -Force "wasm_game_client\www" "$windowsDir\www"
Copy-Item -Recurse -Force "wasm_game_client\www" "$linuxDir\www"

# ============ GO - Gateway ============
Write-Host "`n🐹 Compilando Gateway Go..." -ForegroundColor Yellow

Push-Location $servicesDir\gateway_p_go

Write-Host "  📦 Linux..." -ForegroundColor Gray
$env:GOOS = "linux"
$env:GOARCH = "amd64"
$env:CGO_ENABLED = "0"
go build -o "$linuxDir\gateway_go" .

Write-Host "  📦 Windows..." -ForegroundColor Gray
$env:GOOS = "windows"
$env:GOARCH = "amd64"
$env:CGO_ENABLED = "0"
go build -o "$windowsDir\gateway_go.exe" .

Remove-Item Env:\GOOS
Remove-Item Env:\GOARCH
Remove-Item Env:\CGO_ENABLED

Pop-Location

# ============ BUILD LINUX (via Docker) ============
Write-Host "`n🐧 Compilando para Linux (via Docker)..." -ForegroundColor Yellow

$dockerImageName = "rest-build-linux"
docker build -t $dockerImageName -f scripts\build\Dockerfile.build .

$containerId = docker create $dockerImageName
docker cp "${containerId}:/app/servico_a" "$linuxDir\servico_a"
docker cp "${containerId}:/app/servico_b" "$linuxDir\servico_b"
docker cp "${containerId}:/app/gateway_go" "$linuxDir\gateway_go"
docker rm $containerId

# =================================================


Write-Host "`n✅ BUILD COMPLETO!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Cyan
Write-Host "📁 Binários gerados em:" -ForegroundColor Yellow
Write-Host "   Windows: $windowsDir" -ForegroundColor Gray
Write-Host "`n🚀 Para executar localmente:" -ForegroundColor Yellow
Write-Host "   Windows: cd $windowsDir && .\run.ps1" -ForegroundColor Gray
Write-Host "`n🎮 Após iniciar, acesse: http://localhost:8080" -ForegroundColor Green