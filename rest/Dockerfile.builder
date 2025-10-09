FROM rust:1.70 as rust-builder

WORKDIR /app

COPY . .

RUN cargo build --release --target x86_64-unknown-linux-gnu -p servico_a
RUN cargo build --release --target x86_64-unknown-linux-gnu -p servico_b

FROM debian:bookworm-slim

WORKDIR /app

COPY --from=rust-builder /app/target/x86_64-unknown-linux-gnu/release/servico_a .
COPY --from=rust-builder /app/target/x86_64-unknown-linux-gnu/release/servico_b .
COPY --from=go-builder /app/gateway_go .