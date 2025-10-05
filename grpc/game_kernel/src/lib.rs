use serde::{Deserialize, Serialize};
use std::collections::HashMap;

pub type PlayerId = i32;

#[derive(Serialize, Deserialize, Clone, Copy, PartialEq, Debug)]
pub enum GameStatus {
    WaitingForPlayers, // Corresponde ao valor 0 do Protobuf
    InProgress,        // Corresponde ao valor 1 do Protobuf
    Finished,          // Corresponde ao valor 2 do Protobuf
}

#[derive(Serialize, Deserialize, Clone, Copy, PartialEq, Debug)]
pub enum CellStateEnum {
    Neutral, // Corresponde ao valor 0 do Protobuf
    Owned,   // Corresponde ao valor 1 do Protobuf
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Cell {
    pub state: CellStateEnum,
    pub owner_id: i32,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Player {
    pub id: PlayerId,
    pub x: i32,
    pub y: i32,
    pub color: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct GridRow {
    #[serde(default)]
    pub cells: Vec<Cell>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Grid {
        #[serde(default)]
    pub rows: Vec<GridRow>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct GameState {
    pub status: GameStatus,
    pub width: i32,
    pub height: i32,
    pub grid: Grid,
    #[serde(default)]
    pub players: HashMap<String, Player>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct MovePayload {
    pub player_id: PlayerId,
    pub direction: String,
}

#[derive(Deserialize, Debug)]
pub struct JoinResponse {
    pub player: Player,
    pub error: String,
}

#[derive(Deserialize, Debug)]
pub struct StateResponse {
    pub state: GameState,
}

#[derive(Deserialize, Debug)]
pub struct MoveResponse {
    pub new_state: Option<GameState>,
    pub game_finished: bool,
    pub error: String,
}

impl GameState {
    pub fn get_cell(&self, x: i32, y: i32) -> Option<&Cell> {
        self.grid.rows
            .get(y as usize)?
            .cells
            .get(x as usize)
    }
    
    pub fn get_player(&self, id: PlayerId) -> Option<&Player> {
        self.players.get(&id.to_string())
    }
}