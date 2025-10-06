# gRPC Bidirectional Streaming Example in Go

## Introduction

gRPC bidirectional streaming allows both the client and server to send a stream of messages to each other independently. This is useful for chat systems, live data feeds, or any scenario where both sides need to communicate asynchronously.

In this example, the client can send messages to the server, and the server responds to each message in real time.

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
You will see the server's response for each message you send.

## Files
- `greetbistream.proto`: Protocol Buffers service definition
- `server.go`: gRPC server implementation
- `client.go`: gRPC client implementation
- `go.mod`: Go module definition

## Notes
- The server listens on port 50054 by default.
- The client and server can send and receive messages independently.
