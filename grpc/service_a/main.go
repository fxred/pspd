package main

import (
	"context"
	"fmt"
	"log"
	"net"

	gamemovementpb "service_a/proto/a"
	gamestatepb "service_a/proto/b"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/reflection"
	"google.golang.org/grpc/status"
)

const serviceBAddr = "localhost:50051"

type GameMoveService struct {
	gamemovementpb.UnimplementedGameMoveServiceServer
	stateClient gamestatepb.GameStateServiceClient
}

func NewGameMoveService() (*GameMoveService, error) {
	conn, err := grpc.Dial(serviceBAddr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, fmt.Errorf("falha ao conectar ao Service B: %w", err)
	}

	return &GameMoveService{
		stateClient: gamestatepb.NewGameStateServiceClient(conn),
	}, nil
}


func (s *GameMoveService) ValidateMove(ctx context.Context, req *gamemovementpb.ValidateMoveRequest) (*gamemovementpb.ValidateMoveResponse, error) {
	state := req.CurrentState
	playerID := req.PlayerId
	direction := req.Direction

	player, ok := state.Players[playerID]
	if !ok {
		return &gamemovementpb.ValidateMoveResponse{
			IsValid: false,
			Error:   "Jogador não encontrado",
		}, nil
	}

	nextX, nextY := calculateNextPosition(player.X, player.Y, int32(direction), state.Width, state.Height)

	if nextX == player.X && nextY == player.Y {
		return &gamemovementpb.ValidateMoveResponse{
			IsValid: false,
			Error:   "Movimento inválido: fora dos limites",
		}, nil
	}

	destCell := state.Grid.Rows[nextY].Cells[nextX]
	if destCell.State == gamemovementpb.CellState_OWNED && destCell.OwnerId != playerID {
		return &gamemovementpb.ValidateMoveResponse{
			IsValid: false,
			Error:   "A célula pertence a outro jogador",
		}, nil
	}

	return &gamemovementpb.ValidateMoveResponse{IsValid: true}, nil
}

func (s *GameMoveService) ExecuteMove(ctx context.Context, req *gamemovementpb.ExecuteMoveRequest) (*gamemovementpb.ExecuteMoveResponse, error) {
	stateResp, err := s.stateClient.GetGameState(ctx, &gamestatepb.GetGameStateRequest{})
	if err != nil {
		log.Printf("[Service A] Erro ao obter estado: %v", err)
		return &gamemovementpb.ExecuteMoveResponse{
			Error: "Erro ao comunicar com o serviço de estado",
		}, status.Error(codes.Internal, "falha ao obter estado")
	}

	state := stateResp.State
	playerID := req.PlayerId
	direction := req.Direction

	player, ok := state.Players[playerID]
	if !ok {
		return &gamemovementpb.ExecuteMoveResponse{
			Error: "Jogador não encontrado",
		}, nil
	}

	nextX, nextY := calculateNextPosition(player.X, player.Y, int32(direction), state.Width, state.Height)

	if nextX == player.X && nextY == player.Y {
		return &gamemovementpb.ExecuteMoveResponse{
			Error: "Movimento inválido",
		}, nil
	}

	destCell := state.Grid.Rows[nextY].Cells[nextX]
	if destCell.State == gamestatepb.CellState_OWNED && destCell.OwnerId != playerID {
		return &gamemovementpb.ExecuteMoveResponse{
			Error: "Célula já pertence a outro jogador",
		}, nil
	}

	state.Grid.Rows[nextY].Cells[nextX] = &gamestatepb.Cell{
		State:   gamestatepb.CellState_OWNED,
		OwnerId: playerID,
	}
	player.X = nextX
	player.Y = nextY
	state.Players[playerID] = player

	gameFinished := checkGameFinished(state)
	if gameFinished {
		state.Status = gamestatepb.GameStatus_FINISHED
	}

	_, err = s.stateClient.UpdateGameState(ctx, &gamestatepb.UpdateGameStateRequest{
		State: state,
	})
	if err != nil {
		log.Printf("[Service A] Erro ao atualizar estado: %v", err)
		return &gamemovementpb.ExecuteMoveResponse{
			Error: "Erro ao salvar estado do jogo",
		}, status.Error(codes.Internal, "falha ao atualizar estado")
	}

	log.Printf("[Service A] Jogador %d moveu %v para (%d, %d)", playerID, direction, nextX, nextY)

	return &gamemovementpb.ExecuteMoveResponse{
		NewState:     convertGameState(state),
		GameFinished: gameFinished,
	}, nil
}

func (s *GameMoveService) GetValidMoves(ctx context.Context, req *gamemovementpb.GetValidMovesRequest) (*gamemovementpb.GetValidMovesResponse, error) {
	state := req.CurrentState
	playerID := req.PlayerId

	player, ok := state.Players[playerID]
	if !ok {
		return &gamemovementpb.GetValidMovesResponse{ValidMoves: []*gamemovementpb.ValidMove{}}, nil
	}

	validMoves := []*gamemovementpb.ValidMove{}
	directions := []gamemovementpb.Direction{
		gamemovementpb.Direction_UP,
		gamemovementpb.Direction_DOWN,
		gamemovementpb.Direction_LEFT,
		gamemovementpb.Direction_RIGHT,
	}

	for _, dir := range directions {
		nextX, nextY := calculateNextPosition(player.X, player.Y, int32(dir), state.Width, state.Height)
		if nextX == player.X && nextY == player.Y {
			continue
		}

		destCell := state.Grid.Rows[nextY].Cells[nextX]
		if destCell.State == gamemovementpb.CellState_OWNED && destCell.OwnerId != playerID {
			continue
		}

		validMoves = append(validMoves, &gamemovementpb.ValidMove{
			Direction:    dir,
			DestinationX: nextX,
			DestinationY: nextY,
		})
	}

	return &gamemovementpb.GetValidMovesResponse{ValidMoves: validMoves}, nil
}


func calculateNextPosition(playerX, playerY int32, direction int32, width, height int32) (int32, int32) {
	nextX, nextY := playerX, playerY

	switch direction {
	case int32(gamemovementpb.Direction_UP):
		if playerY > 0 {
			nextY--
		}
	case int32(gamemovementpb.Direction_DOWN):
		if playerY < height-1 {
			nextY++
		}
	case int32(gamemovementpb.Direction_LEFT):
		if playerX > 0 {
			nextX--
		}
	case int32(gamemovementpb.Direction_RIGHT):
		if playerX < width-1 {
			nextX++
		}
	}

	return nextX, nextY
}

func checkGameFinished(state *gamestatepb.GameState) bool {
	for _, row := range state.Grid.Rows {
		for _, cell := range row.Cells {
			if cell.State == gamestatepb.CellState_NEUTRAL {
				return false
			}
		}
	}
	return true
}

func convertGameState(state *gamestatepb.GameState) *gamemovementpb.GameState {
	gridRows := []*gamemovementpb.GridRow{}
	for _, row := range state.Grid.Rows {
		cells := []*gamemovementpb.Cell{}
		for _, c := range row.Cells {
			cells = append(cells, &gamemovementpb.Cell{
				State:   gamemovementpb.CellState(c.State),
				OwnerId: c.OwnerId,
			})
		}
		gridRows = append(gridRows, &gamemovementpb.GridRow{Cells: cells})
	}

	players := map[int32]*gamemovementpb.Player{}
	for id, p := range state.Players {
		players[id] = &gamemovementpb.Player{
			Id:    p.Id,
			X:     p.X,
			Y:     p.Y,
			Color: p.Color,
		}
	}

	return &gamemovementpb.GameState{
		Status:      gamemovementpb.GameStatus(state.Status),
		Width:       state.Width,
		Height:      state.Height,
		Grid:        &gamemovementpb.Grid{Rows: gridRows},
		Players:     players,
		CurrentTurn: 0,
	}
}


func main() {
	port := 50052
	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", port))
	if err != nil {
		log.Fatalf("Falha ao escutar: %v", err)
	}

	gameMoveService, err := NewGameMoveService()
	if err != nil {
		log.Fatalf("Falha ao criar serviço: %v", err)
	}

	grpcServer := grpc.NewServer()
	gamemovementpb.RegisterGameMoveServiceServer(grpcServer, gameMoveService)
	reflection.Register(grpcServer)

	log.Printf("Service A (GameMoveService) rodando na porta %d", port)
	log.Printf("Conectado ao Service B (GameStateService) em %s", serviceBAddr)

	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("Falha ao servir: %v", err)
	}
}