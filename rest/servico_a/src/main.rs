use axum::{
    http::StatusCode,
    response::{Json, IntoResponse, Response},
    routing::post,
    Router,
};
use std::net::SocketAddr;
use game_kernel::*;
use serde_json::json;
//==================================================================================


const SERVICE_B_URL: &str = "http://127.0.0.1:3001";

#[tokio::main]
async fn main() {

    let app = Router::new()
        .route("/game/move", post(handle_move));

    let addr: SocketAddr = "127.0.0.1:3002".parse().unwrap();
    println!("Serviço A (Lógica) rodando em http://{}", addr);
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

enum AppError {
    ServiceBError(reqwest::Error),
    ClientError(StatusCode),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match self {
            AppError::ServiceBError(err) => {
                eprintln!("Erro ao comunicar com o Serviço B: {:?}", err);
                (StatusCode::BAD_GATEWAY, "Erro ao comunicar com um serviço interno.")
            }
            AppError::ClientError(status) => (status, status.canonical_reason().unwrap_or("")),
        };

        (status, Json(json!({ "erro": message }))).into_response()
    }
}

async fn handle_move(
    Json(payload): Json<MovePayload>,
) -> Result<Json<GameState>, AppError> {
    let client = reqwest::Client::new();

    let game_state_url = format!("{}/game/state", SERVICE_B_URL);

    let response = client
        .get(game_state_url)
        .send()
        .await
        .map_err(AppError::ServiceBError)?;

    if !response.status().is_success() {
        eprintln!("Erro ao obter estado do jogo do Serviço B: Status {}", response.status());
        return Err(AppError::ServiceBError(response.error_for_status().unwrap_err()));
    }

    let mut game: GameState = response
        .json()
        .await
        .map_err(AppError::ServiceBError)?;

    if game.status != GameStatus::InProgress {
        return Err(StatusCode::PRECONDITION_FAILED.into());
    }

    let (next_x, next_y, player_id) = {
        let player = match game.players.get(&payload.player_id) {
            Some(p) => p,
            None => return Err(StatusCode::NOT_FOUND.into()),
        };

        let (mut next_x, mut next_y) = (player.x, player.y);
        match payload.direction.as_str() {
            "UP" => if player.y > 0 { next_y -= 1; },
            "DOWN" => if player.y < game.height - 1 { next_y += 1; },
            "LEFT" => if player.x > 0 { next_x -= 1; },
            "RIGHT" => if player.x < game.width - 1 { next_x += 1; },
            _ => return Err(StatusCode::BAD_REQUEST.into()),
        }
        (next_x, next_y, player.id)
    };

    let destination_cell = game.grid[next_y][next_x];
    if destination_cell != CellState::Owned(player_id) && destination_cell != CellState::Neutral {
        return Err(StatusCode::FORBIDDEN.into());
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
        .send()
        .await
        .map_err(AppError::ServiceBError)?;

    Ok(Json(game))
}

impl From<StatusCode> for AppError {
    fn from(sc: StatusCode) -> Self {
        AppError::ClientError(sc)
    }
}