.PHONY: proto run clean install-tools

install-tools:
	go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

	export PATH="$PATH:$(go env GOPATH)/bin"

proto:
	mkdir -p proto
	protoc --go_out=./proto --go_opt=paths=source_relative \
		--go-grpc_out=./proto --go-grpc_opt=paths=source_relative \
		game_state.proto

run:
	go run main.go

deps:
	go mod download
	go mod tidy

build:
	go build -o bin/game-state-server main.go

clean:
	rm -rf proto/*.pb.go
	rm -rf bin/