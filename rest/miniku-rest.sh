#!/bin/bash
set -e

cleanup() {
    echo -e "\nEncerrando o script e parando o port-forward..."
    pkill -P $$ kubectl
    exit 0
}
trap cleanup EXIT INT TERM

YAML_DIR="./k8s"
PJ_SVCS_DIR="./services"


echo "Compilando binários..."
chmod +x ./build.sh
./build.sh


if ! command -v minikube &> /dev/null; then
    echo "Erro: minikube não está instalado"
    exit 1
fi

if minikube status | grep -q "host: Running" 2>/dev/null; then
    echo "Parando minikube..."
    minikube stop
else
    echo "Minikube não está rodando"
fi

echo "ATENÇÃO: Isso irá deletar TODOS os clusters minikube existentes!"
read -p "Deseja continuar? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operação cancelada"
    exit 0
fi

minikube delete --all
minikube start

echo "Construindo imagens Docker..."
docker build -f Dockerfile.gateway -t gateway_go:latest .
docker build -f Dockerfile.a -t servico_a:latest .
docker build -f Dockerfile.b -t servico_b:latest .

pushd $YAML_DIR > /dev/null

echo "Carregando imagens no Minikube..."
minikube image load servico_a:latest
minikube image load servico_b:latest
minikube image load gateway_go:latest

echo "Aplicando manifestos Kubernetes..."
kubectl apply -f gateway_go_deployment.yaml
kubectl apply -f service_a_deployment.yaml
kubectl apply -f service_b_deployment.yaml

echo "🔌 Iniciando port-forward em segundo plano..."
sleep 10
kubectl port-forward service/gateway-go 8000:8000

echo -e "\n Script concluído! O port-forward para 'gateway-go' está ativo."
echo "Pressione [Ctrl+C] para encerrar este script e o port-forward."

wait

popd > /dev/null