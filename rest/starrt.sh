#!/bin/bash
set -e

# --- Configuração Inicial ---
BASE_DIR=$(pwd)
LOG_DIR="$BASE_DIR/logs"
TARGET_DIR="$BASE_DIR/target/release"

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- Funções Auxiliares ---
build_step() {
    local name="$1"
    shift
    echo -n -e " 📦 $name..."
    "$@" &> "$LOG_DIR/build.log"
    if [ $? -ne 0 ]; then
        echo -e " ${RED}❌ ERRO${NC}"
        echo -e "${YELLOW}      A etapa '$name' falhou. Verifique o log em '$LOG_DIR/build.log'.${NC}"
        exit 1
    fi
    echo -e " ${GREEN}✅${NC}"
}

cleanup() {
    echo -e "\n${RED}🛑 Encerrando todos os serviços...${NC}"
    pkill -P $PID_A $PID_B $PID_GATEWAY $PID_WASM 2>/dev/null
    kill $PID_A $PID_B $PID_GATEWAY $PID_WASM 2>/dev/null
    exit
}

# --- Script Principal ---

# 1. Preparação
mkdir -p "$LOG_DIR"
rm -f "$LOG_DIR"/*.log "$LOG_DIR"/*.err "$LOG_DIR"/build.log
trap cleanup INT TERM

# 2. Compilação
echo "--------------------------------------------------"
echo -e "${YELLOW}🚀 Etapa 1: Construindo todos os projetos...${NC}"
build_step "Limpando builds antigos" rm -rf "$BASE_DIR/wasm_game_client/www/pkg"
build_step "Construindo WASM Client" cargo build --target wasm32-unknown-unknown --release --package wasm_game_client
build_step "Executando wasm-bindgen" wasm-bindgen --out-dir "$BASE_DIR/wasm_game_client/www/pkg" --target web "$BASE_DIR/target/wasm32-unknown-unknown/release/wasm_game_client.wasm"
build_step "Construindo Serviço A" cargo build --release --package servico_a
build_step "Construindo Serviço B" cargo build --release --package servico_b

# 3. Inicialização
echo -e "\n${YELLOW}🚀 Etapa 2: Iniciando todos os serviços...${NC}"

"$TARGET_DIR/servico_a" > "$LOG_DIR/servico_a.log" 2> "$LOG_DIR/servico_a.err" &
PID_A=$!

"$TARGET_DIR/servico_b" > "$LOG_DIR/servico_b.log" 2> "$LOG_DIR/servico_b.err" &
PID_B=$!

(cd "$BASE_DIR/gateway_p_go" && go run main.go) > "$LOG_DIR/gateway_go.log" 2> "$LOG_DIR/gateway_go.err" &
PID_GATEWAY=$!

(cd "$BASE_DIR/wasm_game_client/www" && python3 -m http.server 8080) > "$LOG_DIR/client_wasm.log" 2> "$LOG_DIR/client_wasm.err" &
PID_WASM=$!

sleep 2

# 4. Loop Interativo
echo -e "\n--------------------------------------------------"
echo -e "${GREEN}✅ Todos os serviços foram iniciados!${NC}"
echo "   - Cliente web disponível em http://localhost:8080"
echo "   - PIDs: A=$PID_A, B=$PID_B, Gateway=$PID_GATEWAY, WASM=$PID_WASM"
echo "--------------------------------------------------"
echo -e "${YELLOW}Pressione 'r' para resetar o serviço B, 'q' ou Ctrl+C para sair.${NC}"

reset_service_b() {
    echo -e "\n${YELLOW}🔄 Resetando serviço B...${NC}"
    kill $PID_B 2>/dev/null
    wait $PID_B 2>/dev/null
    "$TARGET_DIR/servico_b" > "$LOG_DIR/servico_b.log" 2> "$LOG_DIR/servico_b.err" &
    PID_B=$!
    echo -e "${GREEN}✅ Serviço B reiniciado. Novo PID: $PID_B${NC}"
}

while true; do
    read -rsn1 key
    if [[ "$key" = "r" ]]; then
        reset_service_b
    elif [[ "$key" = "q" ]]; then
        cleanup
    fi
done