use axum::{
    extract::State,
    http::StatusCode,
    response::Json,
    routing::{get, post},
    Router,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use tower_http::cors::{Any, CorsLayer};

// ===================================================================================
// ESTRUTURAS DE DADOS E TIPOS
// ===================================================================================

type PlayerId = u8;

#[derive(Serialize, Deserialize, Clone, Copy, PartialEq, Debug)]
pub enum GameStatus {
    WaitingForPlayers,
    InProgress,
    Finished,
}

#[derive(Serialize, Deserialize, Clone, Copy, PartialEq, Debug)]
pub enum CellState {
    Neutral,
    Owned(PlayerId),
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Player {
    id: PlayerId,
    x: usize,
    y: usize,
    color: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct GameState {
    status: GameStatus,
    width: usize,
    height: usize,
    grid: Vec<Vec<CellState>>,
    players: HashMap<PlayerId, Player>,
}

#[derive(Deserialize)]
pub struct MovePayload {
    player_id: PlayerId,
    direction: String,
}

// ===================================================================================
// FUNÇÃO PRINCIPAL E CONFIGURAÇÃO DO SERVIDOR
// ===================================================================================

#[tokio::main]
async fn main() {
	let cors = CorsLayer::new()
	        .allow_origin(Any)
	        .allow_methods(Any)
	        .allow_headers(Any);

    let initial_state = create_initial_state(15, 15);
    let shared_state = Arc::new(Mutex::new(initial_state));

    let app = Router::new()
        .route("/game", get(get_game_state))
        .route("/game/join", post(join_game))
        .route("/game/move", post(handle_move))
        .with_state(shared_state)
        .layer(cors);

    let addr: SocketAddr = "127.0.0.1:3000".parse().unwrap();
    println!("Servidor rodando em http://{}", addr);
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

// ===================================================================================
// HANDLERS DAS ROTAS DA API
// ===================================================================================

async fn get_game_state(State(state): State<Arc<Mutex<GameState>>>) -> Json<GameState> {
    let game = state.lock().unwrap();
    Json(game.clone())
}

async fn join_game(State(state): State<Arc<Mutex<GameState>>>) -> Result<Json<Player>, StatusCode> {
    let mut game = state.lock().unwrap();

    if game.status != GameStatus::WaitingForPlayers {
        return Err(StatusCode::FORBIDDEN); 
    }

    let positions = [
        (game.width / 2, 0), (game.width / 2, game.height - 1),
        (0, game.height / 2), (game.width - 1, game.height / 2),
    ];
    let colors = ["#FF5733", "#33C4FF", "#A2FF33", "#F733FF"];
    let next_player_id = (game.players.len() + 1) as PlayerId;

    if next_player_id > 4 {
        return Err(StatusCode::FORBIDDEN);
    }

    let pos = positions[(next_player_id - 1) as usize];
    let color = colors[(next_player_id - 1) as usize];

    let new_player = Player { id: next_player_id, x: pos.0, y: pos.1, color: color.to_string() };

    game.players.insert(next_player_id, new_player.clone());
    game.grid[pos.1][pos.0] = CellState::Owned(next_player_id);

    if game.players.len() == 2 {
        game.status = GameStatus::InProgress;
    }

    Ok(Json(new_player))
}

async fn handle_move(
    State(state): State<Arc<Mutex<GameState>>>,
    Json(payload): Json<MovePayload>,
) -> Result<Json<GameState>, StatusCode> {
    let mut game = state.lock().unwrap();

    if game.status != GameStatus::InProgress {
        return Err(StatusCode::PRECONDITION_FAILED);
    }

    let (next_x, next_y, player_id) = {
        let player = match game.players.get(&payload.player_id) {
            Some(p) => p,
            None => return Err(StatusCode::NOT_FOUND),
        };

        let (mut next_x, mut next_y) = (player.x, player.y);
        match payload.direction.as_str() {
            "UP" => if player.y > 0 { next_y -= 1; },
            "DOWN" => if player.y < game.height - 1 { next_y += 1; },
            "LEFT" => if player.x > 0 { next_x -= 1; },
            "RIGHT" => if player.x < game.width - 1 { next_x += 1; },
            _ => return Err(StatusCode::BAD_REQUEST),
        }
        (next_x, next_y, player.id)
    };

    let destination_cell = game.grid[next_y][next_x];
    if destination_cell != CellState::Owned(player_id) && destination_cell != CellState::Neutral {
        return Err(StatusCode::FORBIDDEN);
    }

    game.grid[next_y][next_x] = CellState::Owned(player_id);
    let player = game.players.get_mut(&payload.player_id).unwrap();
    player.x = next_x;
    player.y = next_y;

    Ok(Json(game.clone()))
}

// ===================================================================================
// FUNÇÃO DE INICIALIZAÇÃO
// ===================================================================================

fn create_initial_state(width: usize, height: usize) -> GameState {
    GameState {
        status: GameStatus::WaitingForPlayers,
        width,
        height,
        grid: vec![vec![CellState::Neutral; width]; height],
        players: HashMap::new(),
    }
}
