# gRPC Client Streaming Example in Go

## Introduction

client ->> server
server -> client

Nesse exemplo é implementado o "client streaming" do gRPC que permite que um cliente envie um fluxo de mensagens para o servidor e, em seguida, receba uma única resposta. Isso é útil para cenários em que o cliente precisa enviar um lote de dados, como upload de logs, dados de sensores ou uma lista de itens.

Neste exemplo, o cliente envia vários nomes para o servidor, e o servidor responde com um resumo após todos os nomes serem enviados.

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
From the `client_streaming` directory:
```bash
protoc --go_out=. --go-grpc_out=. greetcstream.proto
```

### 3. Build the server and client
```bash
go mod tidy
go build -o server server.go 
go build -o client client.go 
```

### 4. Run the server
```bash
./server
```

### 5. Run the client (in another terminal)
```bash
./client Alice Bob Carol
```
You should see output like:
```
2025/10/05 Sent name: Alice
2025/10/05 Sent name: Bob
2025/10/05 Sent name: Carol
2025/10/05 Server summary: Received 3 names: [Alice Bob Carol]
```

## Files
- `greetcstream.proto`: Protocol Buffers service definition
- `server.go`: gRPC server implementation
- `client.go`: gRPC client implementation
- `go.mod`: Go module definition

## Notes
- The server listens on port 50053 by default.
- The client sends a stream of names and receives a summary from the server.
