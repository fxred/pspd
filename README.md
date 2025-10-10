# Setup

Para rodar o projeto, é necessário ter instalado na máquina:

- [rustup](https://rustup.rs/)
- [go](https://go.dev/doc/install)
- [ruby](https://www.ruby-lang.org/pt/downloads/)
- [minikube](https://minikube.sigs.k8s.io/docs/start/)
  - Alguns usuários podem não conseguir rodar corretamente o projeto com o Docker que vem junto do minikube. Recomenda-se a instalação do [Docker Desktop](https://docs.docker.com/desktop/)

Após ter os requisitos, siga os seguintes passos:

1. Instalar o wasm-bindgen-cli:
    `cargo install -f wasm-bindgen-cli`
2. Adicionar o wasm32-unknown-unknown como target:
    `rustup target add wasm32-unknown-unknown`

OBS: Alguns usuários podem precisar instalar o Python3 e a `libssl-dev` também.

Agora basta seguir os passos específicos da versão desejada  

- [REST](rest/README-rest.md)  
- [gRPC](grpc/README.md)
