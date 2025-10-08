FROM rust:1.90-slim as builder

RUN apt-get update && apt-get install -y \
    clang \
    libclang-dev \
    curl \
    git \
    libssl-dev \
    pkg-config

RUN rustup default stable

WORKDIR /app

COPY servico_b/Cargo.toml ./
COPY game_kernel /game_kernel

COPY servico_b/. .

RUN cargo build --release --package servico_b

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    curl \
    libssl-dev \
    pkg-config

COPY --from=builder /app/target/release/servico_b /usr/local/bin/servico_b

EXPOSE 3001

CMD ["/usr/local/bin/servico_b"]