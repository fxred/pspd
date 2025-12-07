package main

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"net"
	"sync"
	"time"

	pb "service_b/proto"

	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
	"google.golang.org/protobuf/proto"
)

type GameStateServer struct {
	pb.UnimplementedGameStateServiceServer
	mu    sync.Mutex
	state *pb.GameState
}

func NewGameStateServer(width, height int32) *GameStateServer {
	return &GameStateServer{
		state: createInitialState(width, height),
	}
}

func (s *GameStateServer) GetGameState(ctx context.Context, req *pb.GetGameStateRequest) (*pb.GameStateResponse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	clonedState := proto.Clone(s.state).(*pb.GameState)

	return &pb.GameStateResponse{
		State: clonedState,
	}, nil
}

func (s *GameStateServer) JoinGame(ctx context.Context, req *pb.JoinGameRequest) (*pb.JoinGameResponse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	// REMOVIDO: A verificação de Status. Agora entra gente a qualquer momento (Caos total)
	// if s.state.Status != pb.GameStatus_WAITING_FOR_PLAYERS { ... }

	nextPlayerID := int32(len(s.state.Players) + 1)

	// REMOVIDO: Limite de jogadores
	// if nextPlayerID > 4 { ... }

	// Spawn Aleatório no Mapa
	posX := rand.Int31n(s.state.Width)
	posY := rand.Int31n(s.state.Height)

	// Cor Aleatória
	color := fmt.Sprintf("#%06X", rand.Intn(0xFFFFFF))

	newPlayer := &pb.Player{
		Id:    nextPlayerID,
		X:     posX,
		Y:     posY,
		Color: color,
	}

	if s.state.Players == nil {
		s.state.Players = make(map[int32]*pb.Player)
	}
	s.state.Players[nextPlayerID] = newPlayer

	// Marca a célula inicial
	s.state.Grid.Rows[posY].Cells[posX] = &pb.Cell{
		State:   pb.CellState_OWNED,
		OwnerId: nextPlayerID,
	}

	// Se tiver mais de 1, já considera em progresso (só pra manter compatibilidade de enum)
	if len(s.state.Players) >= 2 {
		s.state.Status = pb.GameStatus_IN_PROGRESS
	}

	log.Printf("Jogador %d entrou na posição (%d, %d)", nextPlayerID, posX, posY)

	return &pb.JoinGameResponse{
		Player: newPlayer,
	}, nil
}

func (s *GameStateServer) UpdateGameState(ctx context.Context, req *pb.UpdateGameStateRequest) (*pb.UpdateGameStateResponse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.state = req.State

	return &pb.UpdateGameStateResponse{
		Success: true,
	}, nil
}

func (s *GameStateServer) RestartGame(ctx context.Context, req *pb.RestartGameRequest) (*pb.RestartGameResponse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.state = createInitialState(s.state.Width, s.state.Height)
	log.Println("O jogo foi reiniciado (Clean Slate)")

	return &pb.RestartGameResponse{}, nil
}

func createInitialState(width, height int32) *pb.GameState {
	grid := &pb.Grid{
		Rows: make([]*pb.GridRow, height),
	}

	for i := int32(0); i < height; i++ {
		row := &pb.GridRow{
			Cells: make([]*pb.Cell, width),
		}
		for j := int32(0); j < width; j++ {
			row.Cells[j] = &pb.Cell{
				State:   pb.CellState_NEUTRAL,
				OwnerId: 0,
			}
		}
		grid.Rows[i] = row
	}

	return &pb.GameState{
		Status:  pb.GameStatus_WAITING_FOR_PLAYERS,
		Width:   width,
		Height:  height,
		Grid:    grid,
		Players: make(map[int32]*pb.Player),
	}
}

func main() {
	// Seed para aleatoriedade
	rand.Seed(time.Now().UnixNano())

	port := 50051
	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", port))
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
	}

	grpcServer := grpc.NewServer()
	
	// AUMENTADO: Mapa agora é 200x200 para aguentar carga
	// Não coloquei "infinito" literal pq o gRPC tem limite de tamanho de mensagem (4MB padrão),
	// e enviar um array infinito quebraria a serialização. 
	// 200x200 = 40.000 células, é pesado o suficiente para estressar a CPU/Rede.
	gameServer := NewGameStateServer(30, 30)
	
	pb.RegisterGameStateServiceServer(grpcServer, gameServer)

	reflection.Register(grpcServer)

	log.Printf("Serviço B de Estado gRPC (Modo Carga Infinita) rodando na porta %d", port)
	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
}