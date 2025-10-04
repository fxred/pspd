Para rodar o projeto, é necessário ter instalado na máquina:

- [rustup](https://rustup.rs/)
- [go](https://go.dev/doc/install)

Passos:

1. Instalar o wasm-bindgen-cli:
    `cargo install -f wasm-bindgen-cli`
2. Adicionar o wasm32-unknown-unknown como target:
    `rustup target add wasm32-unknown-unknown`
3. Executar o script starrt.sh (linux) ou starrt.ps1 (windows)
    `./starrt.sh` ou `./starrt.ps1`

OBS: Alguns usuários podem precisar instalar o Python3 também.
OBS2: Na pasta `game_client` é possível jogar pelo terminal.