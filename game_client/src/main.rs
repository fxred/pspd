use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::io::{self, stdout, Stdout};
use std::time::Duration;

use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    prelude::*,
    widgets::{Block, Borders, Paragraph, Widget},
};
use reqwest::Client;

// ===================================================================================
// ESTRUTURAS DE DADOS (Idênticas às do backend)
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

#[derive(Serialize)]
pub struct MovePayload<'a> {
    player_id: PlayerId,
    direction: &'a str,
}

// ===================================================================================
// CONSTANTES E CONFIGURAÇÃO
// ===================================================================================

const API_BASE_URL: &str = "http://localhost:3000";

// ===================================================================================
// FUNÇÃO PRINCIPAL
// ===================================================================================

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut terminal = init_terminal()?;
    let client = Client::new();

    let my_player: Player = match client.post(format!("{}/game/join", API_BASE_URL)).send().await {
        Ok(resp) => {
            if resp.status().is_success() {
                resp.json().await?
            } else {
                restore_terminal(&mut terminal)?;
                eprintln!("Falha ao entrar no jogo (servidor respondeu com erro): {}", resp.text().await?);
                return Ok(());
            }
        }
        Err(e) => {
            restore_terminal(&mut terminal)?;
            eprintln!("Não foi possível conectar ao servidor: {}", e);
            return Ok(());
        }
    };

    let my_player_id = my_player.id;
    let mut game_state: Option<GameState> = None;

    loop {
        if let Ok(resp) = client.get(format!("{}/game", API_BASE_URL)).send().await {
            if let Ok(state) = resp.json::<GameState>().await {
                game_state = Some(state);
            }
        }

        if let Some(state) = &game_state {
            terminal.draw(|frame| ui(frame, state, my_player_id))?;
        }

        if event::poll(Duration::from_millis(200))? {
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    let mut direction = None;
                    match key.code {
                        KeyCode::Char('w') | KeyCode::Up => direction = Some("UP"),
                        KeyCode::Char('s') | KeyCode::Down => direction = Some("DOWN"),
                        KeyCode::Char('a') | KeyCode::Left => direction = Some("LEFT"),
                        KeyCode::Char('d') | KeyCode::Right => direction = Some("RIGHT"),
                        KeyCode::Char('q') => break,
                        _ => {}
                    }

                    if let Some(dir) = direction {
                        let payload = MovePayload { player_id: my_player_id, direction: dir };
                        let _ = client
                            .post(format!("{}/game/move", API_BASE_URL))
                            .json(&payload)
                            .send()
                            .await;
                    }
                }
            }
        }
    }

    restore_terminal(&mut terminal)?;
    Ok(())
}

// ===================================================================================
// LÓGICA DA INTERFACE (UI)
// ===================================================================================

fn init_terminal() -> io::Result<Terminal<CrosstermBackend<Stdout>>> {
    enable_raw_mode()?;
    let mut stdout = stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    Terminal::new(backend)
}

fn restore_terminal(terminal: &mut Terminal<CrosstermBackend<Stdout>>) -> io::Result<()> {
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()
}

fn ui(frame: &mut Frame, state: &GameState, my_id: PlayerId) {
    let main_layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(3), Constraint::Min(0)])
        .split(frame.area());

    let status_text = match state.status {
        GameStatus::WaitingForPlayers => format!("Aguardando jogadores... ({}/{})", state.players.len(), 2),
        GameStatus::InProgress => format!("Jogo em andamento! Você é o Jogador {}", my_id),
        GameStatus::Finished => "Fim de jogo!".to_string(),
    };
    let status_widget = Paragraph::new(status_text)
        .style(Style::default().fg(Color::Yellow))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL).title("Status"));
    frame.render_widget(status_widget, main_layout[0]);

    let game_block = Block::default().borders(Borders::ALL).title("Mapa");
    let game_area = game_block.inner(main_layout[1]);
    
    frame.render_widget(game_block, main_layout[1]);
    
    let game_widget = GameWidget { state, my_id };
    frame.render_widget(game_widget, game_area);
}


struct GameWidget<'a> {
    state: &'a GameState,
    my_id: PlayerId,
}

impl Widget for GameWidget<'_> {
    fn render(self, area: Rect, buf: &mut Buffer) {
        let state = self.state;
        let my_id = self.my_id;

        let cell_width = (area.width as usize / state.width).max(1);
        let cell_height = (area.height as usize / state.height).max(1);

        for y in 0..state.height {
            for x in 0..state.width {
                let cell_state = state.grid[y][x];
                let symbol = "█";

                let color = match cell_state {
                    CellState::Neutral => Color::DarkGray,
                    CellState::Owned(player_id) => {
                        let player_color_str = &state.players.get(&player_id).unwrap().color;
                        Color::Rgb(
                            u8::from_str_radix(&player_color_str[1..3], 16).unwrap_or(255),
                            u8::from_str_radix(&player_color_str[3..5], 16).unwrap_or(255),
                            u8::from_str_radix(&player_color_str[5..7], 16).unwrap_or(255),
                        )
                    }
                };
                
                for row in 0..cell_height {
                    for col in 0..cell_width {
                        let screen_x = area.x + (x * cell_width) as u16 + col as u16;
                        let screen_y = area.y + (y * cell_height) as u16 + row as u16;
                        if screen_x < area.right() && screen_y < area.bottom() {
                            buf.get_mut(screen_x, screen_y).set_symbol(symbol).set_fg(color);
                        }
                    }
                }
            }
        }

        for player in state.players.values() {
            let symbol = if player.id == my_id { "☻" } else { "☺" };
            let screen_x = area.x + (player.x * cell_width) as u16 + (cell_width / 2) as u16;
            let screen_y = area.y + (player.y * cell_height) as u16 + (cell_height / 2) as u16;
            if screen_x < area.right() && screen_y < area.bottom() {
                buf.get_mut(screen_x, screen_y).set_symbol(symbol).set_fg(Color::White).set_bg(Color::Black);
            }
        }
    }
}
