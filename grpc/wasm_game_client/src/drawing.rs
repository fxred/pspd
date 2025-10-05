use super::utils::document;
use game_kernel::{GameState, GameStatus, PlayerId, CellStateEnum};
use std::collections::HashMap;
use wasm_bindgen::JsCast;
use web_sys::CanvasRenderingContext2d;

pub fn draw_game(ctx: &CanvasRenderingContext2d, state: &GameState, my_id: PlayerId) {
    let canvas = ctx.canvas().unwrap();
    let cell_width = (canvas.width() as f64 / state.width as f64).max(1.0);
    let cell_height = (canvas.height() as f64 / state.height as f64).max(1.0);

    // Fundo
    ctx.set_fill_style_str("#34495e");
    ctx.fill_rect(0.0, 0.0, canvas.width() as f64, canvas.height() as f64);

    // 🔹 Desenha o grid e as células
    for (y, row) in state.grid.rows.iter().enumerate() {
        for (x, cell) in row.cells.iter().enumerate() {
            let color = match cell.state {
                CellStateEnum::Neutral => "#7f8c8d".to_string(),
                CellStateEnum::Owned => state
                    .players
                    .get(&cell.owner_id.to_string())
                    .map_or("#bdc3c7".to_string(), |p| p.color.clone()),
            };

            ctx.set_fill_style_str(&color);
            ctx.fill_rect(
                x as f64 * cell_width,
                y as f64 * cell_height,
                cell_width,
                cell_height,
            );
        }
    }

    // 🔹 Desenha os jogadores
    for player in state.players.values() {
        let center_x = player.x as f64 * cell_width + cell_width / 2.0;
        let center_y = player.y as f64 * cell_height + cell_height / 2.0;

        ctx.begin_path();
        ctx.arc(center_x, center_y, cell_width / 2.5, 0.0, std::f64::consts::PI * 2.0)
            .unwrap();
        ctx.set_fill_style_str(&player.color);
        ctx.fill();
        ctx.set_stroke_style_str("white");
        ctx.set_line_width(2.0);
        ctx.stroke();

        if player.id == my_id {
            ctx.begin_path();
            ctx.arc(center_x, center_y, cell_width / 5.0, 0.0, std::f64::consts::PI * 2.0)
                .unwrap();
            ctx.set_fill_style_str("white");
            ctx.fill();
        }
    }

    let status_element = document()
        .get_element_by_id("status-message")
        .unwrap()
        .dyn_into::<web_sys::HtmlElement>()
        .unwrap();

    let status_text = match state.status {
        GameStatus::WaitingForPlayers => {
            format!("Aguardando jogadores... ({}/{})", state.players.len(), 2)
        }
        GameStatus::InProgress => format!("Jogo em andamento! Você é o Jogador {}", my_id),
        GameStatus::Finished => {
            let mut scores: HashMap<PlayerId, usize> = HashMap::new();
            for row in &state.grid.rows {
                for cell in &row.cells {
                    if cell.state == CellStateEnum::Owned {
                        *scores.entry(cell.owner_id).or_insert(0) += 1;
                    }
                }
            }

            let winner = scores.iter().max_by_key(|&(_, score)| score);

            if let Some((id, _)) = winner {
                format!("Fim de jogo! Vencedor: Jogador {}", id)
            } else {
                "Fim de jogo!".to_string()
            }
        }
    };
    status_element.set_inner_text(&status_text);

    draw_scores(ctx, state);
}

fn draw_scores(ctx: &CanvasRenderingContext2d, state: &GameState) {
    ctx.set_fill_style_str("white");
    ctx.set_font("16px Arial");
    ctx.set_text_align("left");

    let mut player_scores: Vec<_> = state
        .players
        .values()
        .map(|player| {
            let score = state
                .grid
                .rows
                .iter()
                .flat_map(|row| row.cells.iter())
                .filter(|cell| {
                    cell.state == CellStateEnum::Owned && cell.owner_id == player.id
                })
                .count();
            (player, score)
        })
        .collect();

    player_scores.sort_by(|a, b| b.1.cmp(&a.1));

    let mut y_offset = 20.0;
    for (player, score) in player_scores {
        let score_text = format!("Jogador {}: {} pontos", player.id, score);

        ctx.set_fill_style_str(&player.color);
        ctx.fill_rect(10.0, y_offset - 12.0, 12.0, 12.0);

        ctx.set_fill_style_str("white");
        ctx.fill_text(&score_text, 30.0, y_offset).unwrap();
        y_offset += 20.0;
    }
}
