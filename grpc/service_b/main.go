package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"sync"

	pb "service_b/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/reflection"
	"google.golang.org/grpc/status"
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

	return &pb.GameStateResponse{
		State: s.state,
	}, nil
}

func (s *GameStateServer) JoinGame(ctx context.Context, req *pb.JoinGameRequest) (*pb.JoinGameResponse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.state.Status != pb.GameStatus_WAITING_FOR_PLAYERS {
		return &pb.JoinGameResponse{
			Error: "Jogo não aceita novos jogadores",
		}, status.Error(codes.FailedPrecondition, "jogo não está no estado de espera")
	}

	positions := [][2]int32{
		{s.state.Width / 2, 0},
		{s.state.Width / 2, s.state.Height - 1},
		{0, s.state.Height / 2},
		{s.state.Width - 1, s.state.Height / 2},
	}
	colors := []string{"#FF5733", "#33C4FF", "#A2FF33", "#F733FF"}

	nextPlayerID := int32(len(s.state.Players) + 1)

	if nextPlayerID > 4 {
		return &pb.JoinGameResponse{
			Error: "Número máximo de jogadores atingido",
		}, status.Error(codes.ResourceExhausted, "número máximo de jogadores atingido")
	}

	pos := positions[nextPlayerID-1]
	color := colors[nextPlayerID-1]

	newPlayer := &pb.Player{
		Id:    nextPlayerID,
		X:     pos[0],
		Y:     pos[1],
		Color: color,
	}

	if s.state.Players == nil {
		s.state.Players = make(map[int32]*pb.Player)
	}
	s.state.Players[nextPlayerID] = newPlayer

	s.state.Grid.Rows[pos[1]].Cells[pos[0]] = &pb.Cell{
		State:   pb.CellState_OWNED,
		OwnerId: nextPlayerID,
	}

	if len(s.state.Players) == 2 {
		s.state.Status = pb.GameStatus_IN_PROGRESS
	}

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
	port := 50051
	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", port))
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
	}

	grpcServer := grpc.NewServer()
	gameServer := NewGameStateServer(15, 15)
	pb.RegisterGameStateServiceServer(grpcServer, gameServer)
	
	
	reflection.Register(grpcServer)

	log.Printf("Serviço de Estado gRPC rodando na porta %d", port)
	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
}