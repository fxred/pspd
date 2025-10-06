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

# Função para matar processos que estão usando uma porta específica.
# Utiliza 'ss' para encontrar os PIDs, pois 'lsof' pode não estar instalado.
kill_by_port() {
    local port="$1"
    
    # Comando para extrair PIDs de processos em LISTEN na porta.
    # Usando grep/sed para garantir compatibilidade se grep -P não for suportado.
    # ss -tunlp: tcp/udp, numerical, listening, process info
    # grep ":${port} ": filtra pela porta.
    # grep -o 'pid=[0-9]*': extrai apenas a string 'pid=XXXX'.
    # sed 's/pid=//g': remove o prefixo 'pid=' para deixar apenas o número do PID.
    local pids=$(sudo ss -tunlp | grep ":${port} " | grep -o 'pid=[0-9]*' | sed 's/pid=//g' | tr '\n' ' ' || true)
    
    if [ -n "$pids" ]; then
        echo -e "   ${RED}⚠️ Forçando encerramento na porta $port (PIDs: $pids)...${NC}"
        # Convert the space-separated string of PIDs into an array for safe iteration
        local pid_array=($pids) 
        
        # 1. Kill graceful
        kill ${pid_array[@]} 2>/dev/null || true 
        sleep 1
        # 2. Kill forceful
        kill -9 ${pid_array[@]} 2>/dev/null || true 
    fi
}


build_step() {
    local name="$1"
    shift
    echo -n -e " 📦 $name..."
    "$@" >> "$LOG_DIR/build.log" 2>&1
    if [ $? -ne 0 ]; then
        echo -e " ${RED}❌ ERRO${NC}"
        echo -e "${YELLOW}      A etapa '$name' falhou. Verifique o log em '$LOG_DIR/build.log'.${NC}"
        exit 1
    fi
    echo -e " ${GREEN}✅${NC}"
}

cleanup() {
    echo -e "\n${RED}🛑 Encerrando todos os serviços...${NC}"

    # A forma mais robusta de garantir o encerramento é buscar e matar
    # processos que ainda estejam *escutando* nas portas conhecidas.
    echo -e "   Verificando e forçando encerramento de processos ativos nas portas..."

    # Encerramento forçado pelas portas (Mais robusto)
    kill_by_port 3002  # Serviço A
    kill_by_port 3001  # Serviço B
    kill_by_port 8080  # Cliente WASM (Python HTTP Server)
    kill_by_port 8000  # Gateway (Go)

    echo -e "${GREEN}✅ Serviços encerrados.${NC}"
    exit
}

# --- Script Principal ---

# 1. Preparação
trap cleanup INT TERM
mkdir -p "$LOG_DIR"
rm -f "$LOG_DIR"/*.log "$LOG_DIR"/*.err 
> "$LOG_DIR"/build.log

# 2. Compilação
echo "--------------------------------------------------"
echo -e "${YELLOW}🚀 Etapa 1: Construindo todos os projetos...${NC}"
build_step "Limpando builds antigos" rm -rf "$BASE_DIR/wasm_game_client/www/pkg"
build_step "Construindo WASM Client" cargo build --target wasm32-unknown-unknown --release --package wasm_game_client
build_step "Executando wasm-bindgen" wasm-bindgen --out-dir "$BASE_DIR/wasm_game_client/www/pkg" --target web "$BASE_DIR/target/wasm32-unknown-unknown/release/wasm_game_client.wasm"
build_step "Construindo Serviço A" cargo build --release --package servico_a
build_step "Construindo Serviço B" cargo build --release --package servico_b

(cd "$BASE_DIR/gateway_p_go" && build_step "Construindo Gateway P (GO)" go build -o "$TARGET_DIR/gateway_go" .)


# 3. Inicialização
echo -e "\n${YELLOW}🚀 Etapa 2: Iniciando todos os serviços...${NC}"

"$TARGET_DIR/servico_a" > "$LOG_DIR/servico_a.log" 2> "$LOG_DIR/servico_a.err" &
PID_A=$!

"$TARGET_DIR/servico_b" > "$LOG_DIR/servico_b.log" 2> "$LOG_DIR/servico_b.err" &
PID_B=$!

(cd "$BASE_DIR/gateway_p_go" && "$TARGET_DIR/gateway_go") > "$LOG_DIR/gateway_go.log" 2> "$LOG_DIR/gateway_go.err" &
PID_GATEWAY=$!

# Python HTTP Server runs on port 8080
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
    
    # Kill old PID and wait
    kill $PID_B 2>/dev/null || true
    wait $PID_B 2>/dev/null || true
    
    # Robust check: kill anything still listening on service B's assumed ports
    kill_by_port 3001
    kill_by_port 3002

    # Restart service B
    "$TARGET_DIR/servico_b" > "$LOG_DIR/servico_b.log" 2> "$LOG_DIR/servico_b.err" &
    PID_B=$!
    echo -e "${GREEN}✅ Serviço B reiniciado. Novo PID: $PID_B${NC}"
    echo "   - PIDs atuais: A=$PID_A, B=$PID_B, Gateway=$PID_GATEWAY, WASM=$PID_WASM"
}

while true; do
    read -rsn1 key
    if [[ "$key" = "r" ]]; then
        reset_service_b
    elif [[ "$key" = "q" ]]; then
        cleanup
    fi
done
