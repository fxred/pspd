# Setup

Para rodar o projeto, é necessário ter instalado na máquina:

- [rustup](https://rustup.rs/)
- [minikube](https://minikube.sigs.k8s.io/docs/start/)
  - **Alguns usuários** podem não conseguir rodar corretamente o projeto com o Docker que vem junto do Minikube. Recomenda-se a instalação do [Docker Desktop](https://docs.docker.com/desktop/).
- [python3](https://www.python.org/downloads/) (caso não já instalado)

Em distros como Arch Linux, há a necessidade também de instalar o [Docker](https://docs.docker.com/desktop/setup/install/linux/) separadamente.

Também percebeu-se que em algumas máquinas com distros baseadas em Debian, há a necessidade de instalar a `libssl-dev` e `pkg-config`.

Caso queira rodar localmente (sem o Minikube), também há necessidade de instalar Go e Ruby.
- [go](https://go.dev/doc/install)
- [ruby](https://www.ruby-lang.org/pt/downloads/)

Após ter os requisitos, siga os seguintes passos:

1. Instalar o wasm-bindgen-cli:
    `cargo install -f wasm-bindgen-cli`
2. Adicionar o wasm32-unknown-unknown como target:
    `rustup target add wasm32-unknown-unknown`

Agora basta seguir os passos específicos da versão desejada  

- [REST](rest/README-rest.md)  
- [gRPC](grpc/README.md)
