Para rodar a versão rest usando o minikube 
Verifique se possui o
1. Docker Desktop - (mesmo na versão Linux é necessário te o desktop instalado)
2. minikube instalado [Guia](https://minikube.sigs.k8s.io/docs/start/?arch=%2Flinux%2Fx86-64%2Fstable%2Fbinary+download)
3. rustup - Para poder executar o cliente no navegador 
4. python3 - Para poder executar o cliente no navegador 

Depois de verificado os pré-requisitos execute os comandos 

Entrar na pasta rest
`cd rest`

Garantir que o minikube já esteja sendo executado no docker
`minikube start`

Garantir permissão de execução do script .sh
`chmod +x ./miniku-rest.sh`

Executar o script .sh
`./miniku-rest.sh`

No terminal ficará o log 'Forwarding from 127.0.0.1:8000 -> 8000'
Que o redirect da porta 8000 do gateway para porta 8000 do localhost
Por último execute:
`chmod +x ./client_setup.sh`
`./client_setup.sh`

Com isso acesse pelo navegador o endereço 
'http://127.0.0.1:8080/'
ou 
'http://localhost:8080/'

Acesse em uma SEGUNDA ABA o mesmo endereço novamente! 
Com isso teremos 2 players conectados e o jogo funcionará!
Divirta-se
