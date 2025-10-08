FROM rust:latest AS builder
WORKDIR /app

COPY wasm_game_client/Cargo.toml ./
COPY wasm_game_client/src ./src
COPY wasm_game_client/www ./www
COPY game_kernel /game_kernel 

RUN rustup target add wasm32-unknown-unknown
RUN cargo install wasm-bindgen-cli

RUN cargo build --target wasm32-unknown-unknown --release --package wasm_game_client 
 
RUN wasm-bindgen target/wasm32-unknown-unknown/release/wasm_game_client.wasm \
    --out-dir /app/public --target web

COPY wasm_game_client/www/ /app/public/


FROM nginx:alpine AS final
COPY --from=builder /app/public /usr/share/nginx/html

EXPOSE 80