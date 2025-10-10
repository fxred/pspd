# Versão REST

## Rodando com minikube

Desfaça quaisquer alterações feitas nas URLs caso tenha rodado localmente. Após isso, siga os passos:

1. Executar o script `minikube-rest` apropriado.

    ```bash
    ./minikube-rest.sh #Linux
    ./minikube-rest.ps1 #Windows
    ```

    > Este script irá deletar clusters Minikube existentes. Confirme quando solicitado.

2. Execute o script `client_setup` apropriado

    ```bash
    ./client_setup.sh #Linux
    ./client_setup.ps1 #Windows
    ```

3. **Acesse o jogo**  
   - Abra <http://localhost:8080> no navegador
   - **Importante:** Abra uma **segunda aba** no mesmo endereço para conectar 2 jogadores
   - O jogo iniciará automaticamente com 2 jogadores conectados
   - O jogo acaba quando todas as células são capturadas. O vencedor é quem tiver mais células ao final.


## Rodando sem minikube

1. Edite os seguintes arquivos alterando as URLs de `service-a` ou `service-b` para `localhost`:
    - `services/gateway_p_go/main.go`
    - `services/servico_a/src/main.rs`

2. Faça o build do projeto:

    ```bash
    ./build.sh #Linux
    ./build.ps1 #Windows
    ```

3. Entre no diretório `dist` contendo os arquivos para seu sistema operacional (Windows ou Linux) e execute o script `run` apropriado

    ```bash
    ./run.sh #Linux
    ./run.ps1 #Windows
    ```

4. No diretório raiz da versão rest (`/rest`), execute o script `client_setup` apropriado

    ```bash
    ./client_setup.sh #Linux
    ./client_setup.ps1 #Windows
    ```

5. **Acesse o jogo**  
   - Abra <http://localhost:8080> no navegador
   - **Importante:** Abra uma **segunda aba** no mesmo endereço para conectar 2 jogadores
   - O jogo iniciará automaticamente com 2 jogadores conectados
   - **Objetivo:** Capturar mais células que o oponente para vencer!
