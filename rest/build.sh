#!/bin/bash
set -e

echo "🔨 BUILD CROSS-PLATFORM - REST"
echo "================================"
echo ""

DIST_BASE="./dist"
LINUX_DIR="$DIST_BASE/linux"
WINDOWS_DIR="$DIST_BASE/windows"
SERVICES_DIR="./services"

mkdir -p "$LINUX_DIR" "$WINDOWS_DIR"

# ============ RUST ============
echo "🦀 Compilando Serviços Rust..."

cargo install cross

rustup update
rustup target add x86_64-unknown-linux-gnu 2>/dev/null || true
rustup target add x86_64-pc-windows-gnu 2>/dev/null || true
rustup target add wasm32-unknown-unknown 2>/dev/null || true

echo "  📦 Linux..."
cargo build --release --target x86_64-unknown-linux-gnu -p servico_a
cargo build --release --target x86_64-unknown-linux-gnu -p servico_b

echo "  📦 Windows..."
cross build --release --target x86_64-pc-windows-gnu -p servico_a
cross build --release --target x86_64-pc-windows-gnu -p servico_b

cp target/x86_64-unknown-linux-gnu/release/servico_a "$LINUX_DIR/"
cp target/x86_64-unknown-linux-gnu/release/servico_b "$LINUX_DIR/"
cp target/x86_64-pc-windows-gnu/release/servico_a.exe "$WINDOWS_DIR/"
cp target/x86_64-pc-windows-gnu/release/servico_b.exe "$WINDOWS_DIR/"

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
cp -r wasm_game_client/www "$WINDOWS_DIR/"

# ============ GO ============
echo ""
echo "🐹 Compilando Gateway Go..."

pushd "$SERVICES_DIR/gateway_p_go" > /dev/null

echo "  📦 Linux..."
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o "$LINUX_DIR/gateway_go" .

echo "  📦 Windows..."
GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -o "$WINDOWS_DIR/gateway_go.exe" .

popd > /dev/null

chmod +x "$LINUX_DIR/run.sh" 2>/dev/null || true
chmod +x "$LINUX_DIR/servico_a"
chmod +x "$LINUX_DIR/servico_b"
chmod +x "$LINUX_DIR/gateway_go"

echo ""
echo "✅ BUILD COMPLETO!"
echo "================================"
echo "📁 Binários gerados em:"
echo "   Windows: $WINDOWS_DIR"
echo "   Linux:   $LINUX_DIR"
echo ""
echo "🚀 Para executar localmente:"
echo "   Windows: cd $WINDOWS_DIR && pwsh ./run.ps1"
echo "   Linux:   cd $LINUX_DIR && ./run.sh"
echo ""
echo "🎮 Após iniciar, acesse: http://localhost:8080"