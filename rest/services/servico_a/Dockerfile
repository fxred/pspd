FROM debian:bookworm-slim

WORKDIR /app

RUN apt-get update && \
    apt-get install -y ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY ../../dist/linux/servico_a /app/servico_a
RUN chmod +x /app/servico_a

EXPOSE 3002

CMD ["./servico_a"]