# ----------------------------------------------------------------------
# STAGE 1: BUILD (Fábrica de Compilação Go)
# ----------------------------------------------------------------------
FROM golang:alpine AS builder

WORKDIR /app
# Copia os módulos e o código
COPY service_a/go.mod service_a/go.sum ./
RUN go mod download
COPY service_a/main.go . 
# Copia o subdiretório proto (necessário para o gRPC/protobufs)
COPY service_a/proto ./proto

# Compila o binário estático para Linux
# O CGO_ENABLED=0 garante que o binário não dependa de bibliotecas dinâmicas do sistema
ENV CGO_ENABLED=0
RUN go build -o /go-service main.go

# ----------------------------------------------------------------------
# STAGE 2: RUNTIME (Estação de Empacotamento Leve)
# Usa a imagem Alpine, que é minúscula.
# ----------------------------------------------------------------------
FROM alpine:latest
# Define o certificado CA para conexões seguras (muitas vezes necessário)
RUN apk add --no-cache ca-certificates

WORKDIR /
# Copia APENAS o binário compilado da STAGE 1
COPY --from=builder /go-service /go-service

# Porta gRPC padrão (ajuste conforme necessário)
EXPOSE 50051
# Executa o binário
CMD ["/go-service"]