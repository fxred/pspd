#!/bin/bash

BASE_DIR=$(pwd)

cd "$BASE_DIR/servico_a"
cargo run -r &
PID_A=$!

cd "$BASE_DIR/servico_b"
cargo run -r &
PID_B=$!

cd "$BASE_DIR/gateway_p_go"
go run main.go &
PID_GATEWAY=$!

cd "$BASE_DIR/wasm_game_client"
./rezzet.sh &
PID_WASM=$!

echo "Serviços iniciados. PIDs: A=$PID_A B=$PID_B Gateway=$PID_GATEWAY WASM=$PID_WASM"
echo "Comandos: 'r' para resetar serviço B, 'q ou ctrl-c' para sair"

reset_service_b() {
    echo "Resetando serviço B..."
    kill $PID_B 2>/dev/null
    cd "$BASE_DIR/servico_b"
    cargo run -r &
    PID_B=$!
    echo "Serviço B reiniciado. Novo PID: $PID_B"
}


cleanup() {
    echo "Encerrando serviços..."
    kill $PID_A $PID_B $PID_GATEWAY $PID_WASM 2>/dev/null
    exit
}

trap cleanup INT TERM HUP QUIT

while true; do
    read -t 1 -n 1 key
    if [ "$key" = "r" ]; then
        reset_service_b
    elif [ "$key" = "q" ]; then
        cleanup
    fi
done