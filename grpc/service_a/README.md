# Serviço de Movimento do Jogo - gRPC em Go

Serviço gRPC que gerencia o movimento de um jogo de captura de células

## Estrutura do Projeto

```
.
├── game_movement.proto  # Definição do protocolo gRPC
├── main.go              # Implementação do servidor
├── go.mod               # Dependências Go
├── Makefile             # Comandos úteis
└── proto/               # Código gerado (após compilação)
```

## Pré-requisitos

1. **Go 1.21+** instalado
2. **Protocol Buffer Compiler (protoc)** instalado
   ```bash
   # No Ubuntu/Debian
   sudo apt install -y protobuf-compiler
   
   # No macOS
   brew install protobuf
   ```

## Configuração

### 1. Instalar ferramentas necessárias

```bash
make install-tools
```

### 2. Baixar dependências

```bash
make deps
```

### 3. Gerar código a partir do protobuf

```bash
make proto
```

Isso gera os arquivos `.pb.go` dentro da pasta `proto/`.

## Executar o Servidor

```bash
make run
```

O servidor iniciará na porta **50051** (padrão gRPC).

## Testar com grpcurl

Você pode testar o serviço usando `grpcurl`:

```bash
# Instalar grpcurl
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest

# Listar serviços
grpcurl -plaintext localhost:50052 list

# Chamar GetValidMoves
grpcurl -plaintext -d '{
  "current_state": {
    "status": "IN_PROGRESS",
    "width": 3,
    "height": 3,
    "grid": {
      "rows": [
        {"cells": [{"state": "NEUTRAL"}, {"state": "NEUTRAL"}, {"state": "NEUTRAL"}]},
        {"cells": [{"state": "NEUTRAL"}, {"state": "OWNED", "owner_id": 1}, {"state": "NEUTRAL"}]},
        {"cells": [{"state": "NEUTRAL"}, {"state": "NEUTRAL"}, {"state": "NEUTRAL"}]}
      ]
    },
    "players": {
      "1": {"id": 1, "x": 1, "y": 1, "color": "blue"}
    },
    "current_turn": 1
  },
  "player_id": 1
}' localhost:50052 gamemovement.GameMoveService.GetValidMoves
```