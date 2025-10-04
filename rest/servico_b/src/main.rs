use axum::{
    extract::State,
    http::StatusCode,
    response::Json,
    routing::{get, post},
    Router,
};
use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use game_kernel::*;

#[tokio::main]
async fn main() {
    let initial_state = create_initial_state(15, 15);
    let shared_state = Arc::new(Mutex::new(initial_state));

    let app = Router::new()
        .route("/game/join", post(join_game))
        .route("/game/state", get(get_game_state))
        .route("/game/state/update", post(update_game_state))
        .with_state(shared_state);

    let addr: SocketAddr = "127.0.0.1:3001".parse().unwrap();
    println!("Serviço B (Estado) rodando em http://{}", addr);
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

async fn update_game_state(
    State(state): State<Arc<Mutex<GameState>>>,
    Json(new_state): Json<GameState>,
) -> StatusCode {
    let mut game = state.lock().unwrap();
    *game = new_state;
    StatusCode::OK
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
