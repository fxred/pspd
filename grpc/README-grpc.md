# Versão REST

## Rodando com minikube

1. Executar o script `minikube` apropriado

    ```bash
    ./minikube.sh #Linux
    ./minikube.ps1 #Windows
    ```

2. Execute o script `grpclient_setup` apropriado

    ```bash
    ./grpclient_setup.sh #Linux
    ./grpclient_setup.ps1 #Windows
    ```

3. Acesse o WEB CLIENT em <http://localhost:8080>
    - Acesse em uma SEGUNDA ABA o mesmo endereço novamente. Com isso, 2 jogadores estarão conectados e o jogo terá início. O vencedor é quem tiver mais pontos após todas as células serem capturadas.
