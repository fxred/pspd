FROM debian:bookworm-slim

WORKDIR /app

RUN apt-get update && \
    apt-get install -y ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY ./dist/linux/servico_b /app/servico_b
RUN chmod +x /app/servico_b

EXPOSE 3001

CMD ["./servico_b"]