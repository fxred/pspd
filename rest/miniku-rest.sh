#!/bin/bash
set -e

cleanup() {
    echo -e "\nEncerrando o script e parando o port-forward..."
    pkill -P $$ kubectl
    exit 0
}
trap cleanup EXIT INT TERM

YAML_DIR="../k8s-rest"

echo "Reiniciando o Minikube..."
minikube stop
minikube delete --all
minikube start

echo "Construindo imagens Docker..."
docker build -f gateway_p_go/Dockerfile -t gateway_go:latest .
docker build -f servico_a/Dockerfile -t servico_a:latest .
docker build -f servico_b/Dockerfile -t servico_b:latest .
#docker build -f wasm_game_client/Dockerfile -t wasm_client_rest:latest .

pushd $YAML_DIR > /dev/null

echo "Aplicando manifestos Kubernetes..."
kubectl apply -f gateway_go_deployment.yaml
kubectl apply -f service_a_deployment.yaml
kubectl apply -f service_b_deployment.yaml
#kubectl apply -f wasm_client_deployment.yaml

echo "Carregando imagens no Minikube..."
minikube image load servico_a:latest
minikube image load servico_b:latest
minikube image load gateway_go:latest
#minikube image load wasm_client_rest:latest

echo "🔌 Iniciando port-forward em segundo plano..."
kubectl port-forward service/gateway-go 8000:8000 &

sleep 20

#echo "Obtendo URL do serviço wasm-client-rest..."
#minikube service wasm-client-rest --url

echo -e "\n Script concluído! O port-forward para 'gateway-go' está ativo."
echo "Pressione [Ctrl+C] para encerrar este script e o port-forward."

wait

popd > /dev/null