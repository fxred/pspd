#!/bin/bash
set -e

echo "🔨 BUILD CROSS-PLATFORM - REST"
echo "================================"
echo ""

BASE_DIR=$(pwd)
DIST_BASE="$BASE_DIR/dist"
LINUX_DIR="$DIST_BASE/linux"
SERVICES_DIR="./services"

mkdir -p "$LINUX_DIR"

# ============ RUST ============
echo "🦀 Compilando Serviços Rust..."

rustup update
rustup target add x86_64-unknown-linux-gnu 2>/dev/null || true
rustup target add x86_64-pc-windows-gnu 2>/dev/null || true
rustup target add wasm32-unknown-unknown 2>/dev/null || true

echo "  📦 Linux..."
cargo build --release --target x86_64-unknown-linux-gnu -p servico_a
cargo build --release --target x86_64-unknown-linux-gnu -p servico_b

cp target/x86_64-unknown-linux-gnu/release/servico_a "$LINUX_DIR/"
cp target/x86_64-unknown-linux-gnu/release/servico_b "$LINUX_DIR/"

# ============ WASM Client ============
echo ""
echo "🕸️  Compilando WASM Client..."

rm -rf wasm_game_client/www/pkg

echo "  📦 WASM..."
cargo build --release --target wasm32-unknown-unknown -p wasm_game_client

echo "  🔗 Gerando bindings JS..."
wasm-bindgen --out-dir wasm_game_client/www/pkg --target web target/wasm32-unknown-unknown/release/wasm_game_client.wasm

echo "  📦 Copiando arquivos WASM..."
cp -r wasm_game_client/www "$LINUX_DIR/"

# ============ GO ============
echo ""
echo "🐹 Compilando Gateway Go..."

pushd "$SERVICES_DIR/gateway_p_go" > /dev/null

echo "  📦 Linux..."
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o "$LINUX_DIR/gateway_go" .

popd > /dev/null

chmod +x "$LINUX_DIR/run.sh" 2>/dev/null || true
chmod +x "$LINUX_DIR/servico_a"
chmod +x "$LINUX_DIR/servico_b"
chmod +x "$LINUX_DIR/gateway_go"

echo ""
echo "✅ BUILD COMPLETO!"
echo "================================"
echo "📁 Binários gerados em:"
echo "   Linux:   $LINUX_DIR"
echo ""
echo "🚀 Para executar localmente:"
echo "   Linux:   cd $LINUX_DIR && ./run.sh"
echo ""
echo "🎮 Após iniciar, acesse: http://localhost:8080"