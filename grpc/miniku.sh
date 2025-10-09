#!/bin/bash
set -e

minikube stop
minikube delete --all
minikube start --driver=docker

docker build -f gateway_p/Dockerfile -t ruby-gateway:latest .
docker build -f service_a/Dockerfile -t service-a:latest .
docker build -f service_b/Dockerfile -t service-b:latest .

kubectl apply -f ruby-gateway.yaml
kubectl apply -f service-a.yaml
kubectl apply -f service-b.yaml

minikube image load service-a:latest
minikube image load service-b:latest
minikube image load ruby-gateway:latest