use serde::{Deserialize, Serialize};
use std::collections::HashMap;

pub type PlayerId = u8;

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
    pub id: PlayerId,
    pub x: usize,
    pub y: usize,
    pub color: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct GameState {
    pub status: GameStatus,
    pub width: usize,
    pub height: usize,
    pub grid: Vec<Vec<CellState>>,
    pub players: HashMap<PlayerId, Player>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct MovePayload {
    pub player_id: PlayerId,
    pub direction: String,
}