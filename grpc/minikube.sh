#!/bin/bash
set -e

cleanup() {
    echo -e "\nEncerrando o script e parando o port-forward..."
    pkill -P $$ kubectl
    exit 0
}
trap cleanup EXIT INT TERM

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
minikube start --driver=docker

docker build -f gateway_p/Dockerfile -t ruby-gateway:latest .
docker build -f service_a/Dockerfile -t service-a:latest .
docker build -f service_b/Dockerfile -t service-b:latest .

kubectl apply -f ruby-gateway.yaml
kubectl apply -f service-a.yaml
kubectl apply -f service-b.yaml

echo "Carregando imagem do Serviço A..."
minikube image load service-a:latest
echo "Carregando imagem do Serviço B..."
minikube image load service-b:latest
echo "Carregando imagem do Gateway..."
minikube image load ruby-gateway:latest