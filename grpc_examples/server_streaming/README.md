# gRPC Server Streaming Example in Go

## Introduction

client -> server
server ->>> client

Nesse exemplo é implementado uma conexão de server_streaming gRPC que  permite que o servidor envie um fluxo de mensagens em resposta a uma única requisição do cliente. O cliente faz uma requisição e recebe uma sequência de respostas, o que é útil para cenários como atualizações de progresso, logs ou listas de itens.

Neste exemplo, o cliente envia um nome para o servidor, e o servidor responde com um fluxo de mensagens de saudação.

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
From the `server_streaming` directory:
```bash
protoc --go_out=. --go-grpc_out=. greetstream.proto
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
./client Alice
```
You should see output like:
```
2025/10/05 Greeting: Hello Alice! (message 1)
2025/10/05 Greeting: Hello Alice! (message 2)
...
```

## Files
- `greetstream.proto`: Protocol Buffers service definition
- `server.go`: gRPC server implementation
- `client.go`: gRPC client implementation
- `go.mod`: Go module definition

## Notes
- The server listens on port 50052 by default.
- The client receives a stream of 5 greeting messages from the server.
