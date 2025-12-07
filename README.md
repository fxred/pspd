# Area Control

## 1. Requisitos
Para que algumas instalações tenha sucesso, é presuposto que o usuário já tenha docker instalado em sua máquina.

### 1.1 Instalar o kind:
  - Windows
 ```bash
Invoke-WebRequest -Uri https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64 -OutFile "$env:LOCALAPPDATA\bin\kind.exe"
 ```
  - Linux (release binary)
```bash
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64
 ```

### 1.2 Instalar o kubectl no windows
  - Windows
```bash
Invoke-WebRequest -Uri https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64 -OutFile "$env:LOCALAPPDATA\bin\kind.exe"
 ```
  - Linux
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
 ```

### 1.3 Instalar o helm
  - Windows
```bash
Invoke-WebRequest -Uri https://get.helm.sh/helm-v3.13.3-windows-amd64.zip -OutFile helm.zip

Expand-Archive -Path helm.zip -DestinationPath . -Force; Move-Item .\windows-amd64\helm.exe "$env:LOCALAPPDATA\bin\helm.exe" -Force; Remove-Item helm.zip -Force; Remove-Item .\windows-amd64 -Recurse -Force
```
- Linux
```bash
sudo apt-get install curl gpg apt-transport-https --yes

curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

sudo apt-get update

sudo apt-get install helm
```

### 1.4 K9S (opcional) - deve ter o brew instalado
- Instalar o k9s para facilitar o gerenciamento da aplicação
```bash
brew install derailed/k9s/k9s
```

## 2. Comandos

### 2.1 Kind e Helm
```bash
kind create cluster --config kind.yaml

kubectl version --client

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm repo update

helm install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace -f values.yaml --version 79.12.0
```

### 2.2 Build das imagens
```bash
docker build -f gateway_p/Dockerfile -t ruby-gateway:latest .

docker build -f service_a/Dockerfile -t service-a:latest .

docker build -f service_b/Dockerfile -t service-b:latest .
```

#### 2.3 Salvando as imagens docker nos módulos
```bash
kind load docker-image ruby-gateway:latest --name lab

kind load docker-image service-a:latest --name lab

kind load docker-image service-b:latest --name lab
```

#### 2.4 Aplicando os manifestos k8s dos módulos
```bash
kubectl apply -f ruby-gateway.yaml

kubectl apply -f service-a.yaml

kubectl apply -f service-b.yaml
```

#### 2.5 Executar cliente local
```bash
./grpclient_setup.ps1
ou
./grpclient_setup.sh
```

#### 2.6 Port-forward para o grafana
```bash
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
```

### 2.7 Autentincação grafana web
```bash
user: admin
pass: admin 
```

## 3. Portas 
```bash
localhost:3000

localhost:8080 (game_client)
```














