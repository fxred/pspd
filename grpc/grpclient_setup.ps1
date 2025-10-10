$ErrorActionPreference = "Stop"

if (Test-Path "wasm_game_client/www/pkg") {
    Remove-Item -Recurse -Force "wasm_game_client/www/pkg"
}

cargo build --target wasm32-unknown-unknown --release --package wasm_game_client

wasm-bindgen target/wasm32-unknown-unknown/release/wasm_game_client.wasm `
  --out-dir wasm_game_client/www/pkg `
  --target web

$MINIKUBE_IP = minikube ip
"export const MINIKUBE_IP = '$MINIKUBE_IP';" | Set-Content -Path "wasm_game_client/www/config.js"

Set-Location wasm_game_client/www

python -m http.server 8080