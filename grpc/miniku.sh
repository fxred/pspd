#!/bin/bash
set -e

minikube stop
minikube delete --all
minikube start

docker build -f gateway_p/Dockerfile -t ruby-gateway:latest .
docker build -f service_a/Dockerfile -t service-a:latest .
docker build -f service_b/Dockerfile -t service-b:latest .
docker build -f wasm_game_client/Dockerfile -t wasm-client:latest .

kubectl apply -f ruby-gateway.yaml
kubectl apply -f service-a.yaml
kubectl apply -f service-b.yaml
kubectl apply -f wasm-client.yaml

minikube image load service-a:latest
minikube image load service-b:latest
minikube image load ruby-gateway:latest
minikube image load wasm-client:latest

kubectl port-forward service/ruby-gateway-service 8082:8082
minikube service wasm-client-service --url
