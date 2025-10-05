.PHONY: proto proto-a proto-b proto-ruby run-all run-a run-b run-ruby clean install-tools deps-all setup

install-tools:
	go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

install-ruby-tools:
	gem install grpc grpc-tools google-protobuf sinatra json webrick
	@which grpc_tools_ruby_protoc || echo "⚠️  grpc_tools_ruby_protoc not found in PATH"

setup: install-tools
	mkdir -p service_a/proto service_b/proto gateway_p/lib

proto-a:
	cd service_a && make proto

proto-b:
	cd service_b && make proto

proto: proto-a proto-b
	@echo "Gerando proto"

proto-ruby:
	@mkdir -p gateway_p/lib
	grpc_tools_ruby_protoc -I . \
		--ruby_out=gateway_p/lib \
		--grpc_out=gateway_p/lib \
		service_b/game_state.proto
	grpc_tools_ruby_protoc -I . \
		--ruby_out=gateway_p/lib \
		--grpc_out=gateway_p/lib \
		service_a/game_movement.proto

deps-all:
	cd service_a && go mod tidy
	cd service_b && go mod tidy

run-a:
	cd service_a && go run main.go

run-b:
	cd service_b && go run main.go

run-ruby:
	cd gateway_p && ruby gateway_p_ruby.rb

run-all:
	@mkdir -p logs
	@cd service_a && go run main.go > ./logs/service_a.log 2>&1 & echo $$! > ./logs/service_a.pid
	@sleep 2
	@cd service_b && go run main.go > ./logs/service_b.log 2>&1 & echo $$! > ./logs/service_b.pid
	@sleep 2
	@cd gateway_p && ruby gateway_p_ruby.rb > ./logs/gateway_p.log 2>&1 & echo $$! > ./logs/gateway_p.pid
	@echo "✅ Todos os servidores subiram"
	@echo ""
	@echo "Service A (Move):  http://localhost:50051 (gRPC)"
	@echo "Service B (State): http://localhost:50052 (gRPC)"
	@echo "Ruby Gateway:      http://localhost:8080 (HTTP)"

status:
	@grpcurl -plaintext localhost:50051 list > /dev/null 2>&1 && echo "✅ Service A (Move) - :50051" || echo "❌ Service A - Not running"
	@grpcurl -plaintext localhost:50052 list > /dev/null 2>&1 && echo "✅ Service B (State) - :50052" || echo "❌ Service B - Not running"
	@curl -s http://localhost:8080/ > /dev/null 2>&1 && echo "✅ Ruby Gateway - :8080" || echo "❌ Ruby Gateway - Not running"

kill:
	@[ -f /tmp/service_a.pid ] && kill $$(cat /tmp/service_a.pid) 2>/dev/null || true
	@[ -f /tmp/service_b.pid ] && kill $$(cat /tmp/service_b.pid) 2>/dev/null || true
	@[ -f /tmp/gateway_p.pid ] && kill $$(cat /tmp/gateway_p.pid) 2>/dev/null || true
	@rm -f /tmp/service_*.pid /tmp/gateway_p.pid
	@rm -f /tmp/service_*.log /tmp/gateway_p.log

logs:
	@tail -20 /tmp/service_a.log 2>/dev/null || echo "No logs yet"
	@tail -20 /tmp/service_b.log 2>/dev/null || echo "No logs yet"
	@tail -20 /tmp/gateway_p.log 2>/dev/null || echo "No logs yet"

clean:
	find service_a/proto -name "*.pb.go" -delete 2>/dev/null || true
	find service_b/proto -name "*.pb.go" -delete 2>/dev/null || true
	find gateway_p/lib -name "*_pb.rb" -delete 2>/dev/null || true

test-http:
	curl -X POST http://localhost:8080/create_game \
		-H "Content-Type: application/json" \
		-d '{"width": 5, "height": 5}'
	@echo "\n\n"
	curl -X POST http://localhost:8080/join_game -H "Content-Length: 0"
	@echo "\n\n"
	curl -X POST http://localhost:8080/join_game -H "Content-Length: 0"
	@echo "\n\n"
	curl http://localhost:8080/game_state

test-grpc:
	grpcurl -plaintext -d '{}' localhost:50051 gamestate.GameStateService/JoinGame
	grpcurl -plaintext -d '{}' localhost:50051 gamestate.GameStateService/GetGameState