# ----------------------------------------------------------------------
# STAGE 1: BUILD (Fábrica de Compilação Rust/WASM)
# ----------------------------------------------------------------------
FROM rust:latest AS builder
WORKDIR /app

# Copia os arquivos de configuração do Rust RELATIVOS À PASTA WASM_GAME_CLIENT
# O caminho é PREFIXADO com 'wasm_game_client/' porque o contexto (CWD) é a raiz.
COPY wasm_game_client/Cargo.toml ./
COPY wasm_game_client/src ./src
COPY wasm_game_client/www ./www
COPY game_kernel /game_kernel 

# Instala o target WASM e as ferramentas de binding
RUN rustup target add wasm32-unknown-unknown
RUN cargo install wasm-bindgen-cli

# Compila o código Rust para WASM e gera o binário
RUN cargo build --target wasm32-unknown-unknown --release --package wasm_game_client 
 
# Roda o wasm-bindgen para gerar o código "cola" (glue code) JS
# Assumindo que seu .wasm se chama 'wasm_game_client.wasm'
RUN wasm-bindgen target/wasm32-unknown-unknown/release/wasm_game_client.wasm \
    --out-dir /app/public --target web

# Copia os arquivos estáticos (o que está na pasta 'www' e o 'src/index.html')
# Assumindo que a sua página HTML está em wasm_game_client/www/index.html
COPY wasm_game_client/www/ /app/public/


# ----------------------------------------------------------------------
# STAGE 2: RUNTIME (Estação de Empacotamento Leve com NGINX)
# ----------------------------------------------------------------------
FROM nginx:alpine AS final
# Copia APENAS os artefatos compilados (.wasm e .js) e o HTML estático
COPY --from=builder /app/public /usr/share/nginx/html

# A porta padrão do NGINX
EXPOSE 80
# O NGINX inicia automaticamente e serve o frontend