#!/bin/bash
set -e

cleanup() {
    echo -e "\n🛑 Encerrando os serviços..."
    pkill -P $$
    exit 0
}

trap 'cleanup' EXIT INT TERM

export SERVICE_A_URL="http://localhost:3002"
export SERVICE_B_URL="http://localhost:3001"

echo "🚀 Iniciando serviços..."
echo "   - SERVICE_A_URL: $SERVICE_A_URL"
echo "   - SERVICE_B_URL: $SERVICE_B_URL"
echo ""

./servico_a &
./servico_b &
./gateway_go &
python3 -m http.server 8080 --directory "./www" &

echo "✅ Serviços iniciados em background."
echo "🎮 Acesse: http://localhost:8080"
echo "👉 Pressione [Ctrl+C] para encerrar."

wait -n