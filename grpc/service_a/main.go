package main

import (
	"context"
	"fmt"
	"log"
	"net"

	pb "service_a/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

type GameMoveService struct {
	pb.UnimplementedGameMoveServiceServer
}

func NewGameMoveService() *GameMoveService {
	return &GameMoveService{}
}

func (s *GameMoveService) ValidateMove(ctx context.Context, req *pb.ValidateMoveRequest) (*pb.ValidateMoveResponse, error) {
	state := req.CurrentState
	playerID := req.PlayerId
	direction := req.Direction

	player, exists := state.Players[playerID]
	if !exists {
		return &pb.ValidateMoveResponse{
			IsValid: false,
			Error:   "Jogador não encontrado",
		}, nil
	}

	nextX, nextY := calculateNextPosition(player, direction, state)
	
	if nextX == player.X && nextY == player.Y {
		return &pb.ValidateMoveResponse{
			IsValid: false,
			Error:   "Não pode se mover para fora dos limites da grade",
		}, nil
	}

	destCell := state.Grid.Rows[nextY].Cells[nextX]
	if destCell.State == pb.CellState_OWNED && destCell.OwnerId != playerID {
		return &pb.ValidateMoveResponse{
			IsValid: false,
			Error:   "A célula é propriedade de outro jogador",
		}, nil
	}

	return &pb.ValidateMoveResponse{
		IsValid: true,
	}, nil
}

func (s *GameMoveService) ExecuteMove(ctx context.Context, req *pb.ExecuteMoveRequest) (*pb.ExecuteMoveResponse, error) {
	state := req.CurrentState
	playerID := req.PlayerId
	direction := req.Direction

	validateResp, err := s.ValidateMove(ctx, &pb.ValidateMoveRequest{
		CurrentState: state,
		PlayerId:     playerID,
		Direction:    direction,
	})
	if err != nil || !validateResp.IsValid {
		return &pb.ExecuteMoveResponse{
			Error: validateResp.Error,
		}, nil
	}

	player := state.Players[playerID]
	nextX, nextY := calculateNextPosition(player, direction, state)

	state.Grid.Rows[nextY].Cells[nextX] = &pb.Cell{
		State:   pb.CellState_OWNED,
		OwnerId: playerID,
	}

	player.X = nextX
	player.Y = nextY

	state.CurrentTurn = getNextPlayerTurn(state)

	gameFinished := checkGameFinished(state)
	if gameFinished {
		state.Status = pb.GameStatus_FINISHED
	}

	log.Printf("[Service A] Jogador %d moveu %v o (%d, %d)", playerID, direction, nextX, nextY)

	return &pb.ExecuteMoveResponse{
		NewState:     state,
		GameFinished: gameFinished,
	}, nil
}

func (s *GameMoveService) GetValidMoves(ctx context.Context, req *pb.GetValidMovesRequest) (*pb.GetValidMovesResponse, error) {
	state := req.CurrentState
	playerID := req.PlayerId

	player, exists := state.Players[playerID]
	if !exists {
		return &pb.GetValidMovesResponse{
			ValidMoves: []*pb.ValidMove{},
		}, nil
	}

	validMoves := []*pb.ValidMove{}
	directions := []pb.Direction{
		pb.Direction_UP,
		pb.Direction_DOWN,
		pb.Direction_LEFT,
		pb.Direction_RIGHT,
	}

	for _, dir := range directions {
		nextX, nextY := calculateNextPosition(player, dir, state)

		if nextX == player.X && nextY == player.Y {
			continue
		}

		destCell := state.Grid.Rows[nextY].Cells[nextX]
		if destCell.State == pb.CellState_OWNED && destCell.OwnerId != playerID {
			continue
		}

		validMoves = append(validMoves, &pb.ValidMove{
			Direction:    dir,
			DestinationX: nextX,
			DestinationY: nextY,
		})
	}

	return &pb.GetValidMovesResponse{
		ValidMoves: validMoves,
	}, nil
}

func calculateNextPosition(player *pb.Player, direction pb.Direction, state *pb.GameState) (int32, int32) {
	nextX, nextY := player.X, player.Y

	switch direction {
	case pb.Direction_UP:
		if player.Y > 0 {
			nextY--
		}
	case pb.Direction_DOWN:
		if player.Y < state.Height-1 {
			nextY++
		}
	case pb.Direction_LEFT:
		if player.X > 0 {
			nextX--
		}
	case pb.Direction_RIGHT:
		if player.X < state.Width-1 {
			nextX++
		}
	}

	return nextX, nextY
}

func getNextPlayerTurn(state *pb.GameState) int32 {
	playerIDs := []int32{}
	for id := range state.Players {
		playerIDs = append(playerIDs, id)
	}

	if len(playerIDs) == 0 {
		return 0
	}

	for i, id := range playerIDs {
		if id == state.CurrentTurn {
			return playerIDs[(i+1)%len(playerIDs)]
		}
	}

	return playerIDs[0]
}

func checkGameFinished(state *pb.GameState) bool {
	for _, row := range state.Grid.Rows {
		for _, cell := range row.Cells {
			if cell.State == pb.CellState_NEUTRAL {
				return false
			}
		}
	}
	return true
}

func main() {
	port := 50052
	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", port))
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
	}

	grpcServer := grpc.NewServer()
	gameMoveServer := NewGameMoveService()
	pb.RegisterGameMoveServiceServer(grpcServer, gameMoveServer)
	reflection.Register(grpcServer)

	log.Printf("Serviço A de Movimento gRPC rodando na porta %d", port)
	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
}