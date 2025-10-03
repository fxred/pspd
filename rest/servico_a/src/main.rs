use axum::{
    http::StatusCode,
    response::Json,
    routing::post,
    Router,
};
use std::net::SocketAddr;
use tower_http::cors::{Any, CorsLayer};
use game_kernel::*;

//==================================================================================


const SERVICE_B_URL: &str = "http://127.0.0.1:3001";

#[tokio::main]
async fn main() {
	let cors = CorsLayer::new()
	        .allow_origin(Any)
	        .allow_methods(Any)
	        .allow_headers(Any);

    let app = Router::new()
        .route("/game/move", post(handle_move))
        .layer(cors);

    let addr: SocketAddr = "127.0.0.1:3002".parse().unwrap();
    println!("Serviço A (Lógica) rodando em http://{}", addr);
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn handle_move(
    Json(payload): Json<MovePayload>,
) -> Result<Json<GameState>, StatusCode> {
    let client = reqwest::Client::new();

    let mut game: GameState = client
        .get(format!("{}/game/state/", SERVICE_B_URL))
        .send().await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .json().await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

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

    let has_neutral_cells = game.grid.iter().any(|row| row.iter().any(|&cell| cell == CellState::Neutral));

    if !has_neutral_cells {
        game.status = GameStatus::Finished;
    }

    client.post(format!("{}/game/state/update", SERVICE_B_URL))
        .json(&game)
        .send().await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(game))
}