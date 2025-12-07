<!-- instalar o kind -->
Invoke-WebRequest -Uri https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64 -OutFile "$env:LOCALAPPDATA\bin\kind.exe"

<!-- Criar arquivo kind.yaml -->
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: lab
nodes:
  - role: control-plane   # "manager"
  - role: worker
  - role: worker
```

<!-- Executar -->
kind create cluster --config kind.yaml

<!-- instalar o kubectlm já estava instalado por causa do docker desktop -->
kubectl version --client

<!-- instalar o helm -->
Invoke-WebRequest -Uri https://get.helm.sh/helm-v3.13.3-windows-amd64.zip -OutFile helm.zip

Expand-Archive -Path helm.zip -DestinationPath . -Force; Move-Item .\windows-amd64\helm.exe "$env:LOCALAPPDATA\bin\helm.exe" -Force; Remove-Item helm.zip -Force; Remove-Item .\windows-amd64 -Recurse -Force

<!-- adicionar o repositorio do kube-prometheus-stack no helm instalar o repositorio do kube-prometheus no cluster -->
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm repo update

<!-- Criar o values.yaml -->

helm install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace -f values.yaml --version 79.12.0

instalar o k9s(pra facilitar)

<!-- buildar img do jogo -->
docker build -f gateway_p/Dockerfile -t ruby-gateway:latest .
docker build -f service_a/Dockerfile -t service-a:latest .
docker build -f service_b/Dockerfile -t service-b:latest .

kind load docker-image ruby-gateway:latest --name lab
kind load docker-image service-a:latest --name lab
kind load docker-image service-b:latest --name lab

kubectl apply -f ruby-gateway.yaml
kubectl apply -f service-a.yaml
kubectl apply -f service-b.yaml

<!-- Executar o client localmente -->
./grpclient_setup.ps1
ou
./grpclient_setup.sh

<!-- Port-foward no k9s -->
k9s
<!-- Depois no rubygateway aperta "shift + f" + ok -->

<!-- Port-foward do grafana  -->
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring

<!-- Agora entrar na url do grafana + credencial-->
user: admin
pass: admin 

localhost:3000

<!-- Agora entrar url do gameclient -->
localhost:8080















