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

COPY servico_a/Cargo.toml ./
COPY game_kernel /game_kernel

COPY servico_a/. .

RUN cargo build --release --package servico_a

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    curl \
    libssl-dev \
    pkg-config

COPY --from=builder /app/target/release/servico_a /usr/local/bin/servico_a

EXPOSE 3002

CMD ["/usr/local/bin/servico_a"]