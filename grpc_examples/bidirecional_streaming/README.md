# gRPC Bidirectional Streaming Example in Go

## Introduction

client <---> server
server <---> client

Nesse exemplo é implementado o streaming bidirecional do gRPC que permite tanto o cliente quanto o servidor enviarem fluxos de mensagens um para o outro de forma independente. Isso é útil para sistemas de chat, transmissões de dados em tempo real ou qualquer cenário em que ambos os lados precisem se comunicar de maneira assíncrona.

**Agora, o servidor funciona como uma sala de chat: toda mensagem enviada por um cliente é transmitida (broadcast) para todos os outros clientes conectados em tempo real.**

## Step-by-step Instructions

### 1. Install Prerequisites
- Go (>= 1.20)
- Protocol Buffers compiler (`protoc`)
- gRPC and protobuf Go plugins:
  ```bash
  go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
  go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
  export PATH="$PATH:$(go env GOPATH)/bin"
  ```

### 2. Generate Go code from proto
From the `bidirecional_streaming` directory:
```bash
protoc --go_out=. --go-grpc_out=. greetbistream.proto
```

### 3. Build the server and client
```bash
go build -o server server.go 
go build -o client client.go 
```

### 4. Run the server
```bash
./server
```

### 5. Run the client (in another terminal)
```bash
./client
```
Type your name and message in the format:
```
Alice: Hello!
Bob: Hi Alice!
```
Todas as mensagens enviadas por um cliente serão recebidas por todos os outros clientes conectados, simulando uma sala de chat em tempo real.

## Files
- `greetbistream.proto`: Protocol Buffers service definition
- `server.go`: gRPC server implementation
- `client.go`: gRPC client implementation
- `go.mod`: Go module definition

## Notes
- The server listens on port 50054 by default.
- The client and server can send and receive messages independently.
