# Simple gRPC Unary Example in Go

This example demonstrates a minimal gRPC unary connection in Go. The client sends a single request and receives a single response from the server.

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
From the `simple_unary_go` directory:
```bash
protoc --go_out=. --go-grpc_out=. helloworld.proto
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
2025/10/05 Greeting: Hello, Alice!
```

## Files
- `helloworld.proto`: Protocol Buffers service definition
- `server.go`: gRPC server implementation
- `client.go`: gRPC client implementation
- `go.mod`: Go module definition

## Notes
- The server listens on port 50051 by default.
- You can change the name sent by the client by passing a different argument.
