use super::utils::{document};
use game_kernel::{GameState, GameStatus, Player, PlayerId, CellStateEnum};
use std::collections::HashMap;
use wasm_bindgen::JsCast;
use web_sys::{CanvasRenderingContext2d, HtmlElement};

pub fn draw_game(ctx: &CanvasRenderingContext2d, state: &GameState, my_id: PlayerId) {
    let canvas = ctx.canvas().unwrap();
    let cell_width = (canvas.width() as f64 / state.width as f64).max(1.0);
    let cell_height = (canvas.height() as f64 / state.height as f64).max(1.0);

    // Fundo
    ctx.set_fill_style_str("#34495e");
    ctx.fill_rect(0.0, 0.0, canvas.width() as f64, canvas.height() as f64);

    // Desenha o grid e as células
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

    // Desenha os jogadores
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

    update_info_panel(state, my_id);
}

fn update_info_panel(state: &GameState, my_id: PlayerId) {
    let doc = document();
    let player_id_display = doc.get_element_by_id("player-id-display").unwrap().dyn_into::<HtmlElement>().unwrap();
    let winner_display = doc.get_element_by_id("winner-display").unwrap().dyn_into::<HtmlElement>().unwrap();
    let scores_container = doc.get_element_by_id("scores").unwrap().dyn_into::<HtmlElement>().unwrap();

    // Limpa o conteúdo anterior
    winner_display.set_inner_text("");
    scores_container.set_inner_html("");

    match state.status {
        GameStatus::WaitingForPlayers => {
            player_id_display.set_inner_text(&format!("Aguardando... Você é o Jogador {}", my_id));
        }
        GameStatus::InProgress => {
            player_id_display.set_inner_text(&format!("Você é o Jogador {}", my_id));
            draw_scores_html(scores_container, state);
        }
        GameStatus::Finished => {
            player_id_display.set_inner_text(&format!("Você é o Jogador {}", my_id));
            draw_scores_html(scores_container, state);

            let winner_id = calculate_winner(state);
            if let Some(id) = winner_id {
                let winner_info = state.players.get(&id.to_string()).unwrap();
                winner_display.set_inner_html(&format!(
                    "Fim de Jogo! <span style='color: {}; font-weight: bold;'>Vencedor: Jogador {}</span>",
                    winner_info.color, id
                ));
            } else {
                winner_display.set_inner_text("Fim de Jogo! Empate!");
            }
            
            // Mostra o botão de reiniciar
            if let Some(btn) = doc.get_element_by_id("restart-button") {
                btn.dyn_into::<HtmlElement>().unwrap().style().set_property("display", "block").unwrap();
            }
        }
    }
}

fn draw_scores_html(container: HtmlElement, state: &GameState) {
    let mut player_scores: Vec<(&Player, usize)> = state
        .players
        .values()
        .map(|player| {
            let score = state
                .grid
                .rows
                .iter()
                .flat_map(|row| row.cells.iter())
                .filter(|cell| cell.state == CellStateEnum::Owned && cell.owner_id == player.id)
                .count();
            (player, score)
        })
        .collect();

    // Ordena por score (desc) e depois por ID (asc) para estabilidade
    player_scores.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.id.cmp(&b.0.id)));

    let mut scores_html = String::new();
    for (player, score) in player_scores {
        scores_html.push_str(&format!(
            r#"<div class="score-box" style="color: {};">Jogador {}: {}</div>"#,
            player.color, player.id, score
        ));
    }
    container.set_inner_html(&scores_html);
}

fn calculate_winner(state: &GameState) -> Option<PlayerId> {
    let mut scores: HashMap<PlayerId, usize> = HashMap::new();
    for row in &state.grid.rows {
        for cell in &row.cells {
            if cell.state == CellStateEnum::Owned {
                *scores.entry(cell.owner_id).or_insert(0) += 1;
            }
        }
    }
    scores.into_iter().max_by_key(|&(_, score)| score).map(|(id, _)| id)
}
