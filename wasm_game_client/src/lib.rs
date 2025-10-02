use std::cell::RefCell;
use std::collections::HashMap;
use std::rc::Rc;
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;
use wasm_bindgen_futures::spawn_local;
use web_sys::{CanvasRenderingContext2d, HtmlCanvasElement, KeyboardEvent};

// ===================================================================================
// ESTRUTURAS DE DADOS (copiadas do backend)
// ===================================================================================

type PlayerId = u8;

#[derive(serde::Serialize, serde::Deserialize, Clone, Copy, PartialEq, Debug)]
pub enum GameStatus { WaitingForPlayers, InProgress, Finished }
#[derive(serde::Serialize, serde::Deserialize, Clone, Copy, PartialEq, Debug)]
pub enum CellState { Neutral, Owned(PlayerId) }
#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub struct Player { id: PlayerId, x: usize, y: usize, color: String }
#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub struct GameState { status: GameStatus, width: usize, height: usize, grid: Vec<Vec<CellState>>, players: HashMap<PlayerId, Player> }
#[derive(serde::Serialize)]
pub struct MovePayload<'a> { player_id: PlayerId, direction: &'a str }

// ===================================================================================
// CONSTANTES E CONFIGURAÇÃO
// ===================================================================================

const API_BASE_URL: &str = "http://localhost:3000";

// ===================================================================================
// LÓGICA PRINCIPAL DA APLICAÇÃO WASM
// ===================================================================================

#[wasm_bindgen(start)]
pub async fn main_wasm() {
    console_error_panic_hook::set_once();

    if let Err(e) = run_app().await {
        log(&format!("Erro crítico durante a inicialização: {:?}", e));
    }
}

async fn run_app() -> Result<(), JsValue> {
    let my_player: Rc<RefCell<Option<Player>>> = Rc::new(RefCell::new(None));
    let game_state: Rc<RefCell<Option<GameState>>> = Rc::new(RefCell::new(None));

    let client = reqwest::Client::new();
    log("Tentando entrar no jogo em /game/join...");
    
    let resp = client.post(format!("{}/game/join", API_BASE_URL)).send().await
        .map_err(|e| JsValue::from_str(&format!("Erro de rede ao tentar /join: {}", e)))?;
    
    if resp.status().is_success() {
        let player = resp.json::<Player>().await
            .map_err(|e| JsValue::from_str(&format!("Erro ao decodificar JSON do jogador: {}", e)))?;
        log(&format!("Entrou com sucesso como Jogador {}", player.id));
        *my_player.borrow_mut() = Some(player);
    } else {
        let err_text = resp.text().await
            .map_err(|e| JsValue::from_str(&format!("Erro ao ler corpo da resposta de erro: {}", e)))?;
        return Err(JsValue::from_str(&format!("Falha ao entrar no jogo: {}", err_text)));
    }
    
    let my_player_clone_for_move = my_player.clone();
    let client_clone_for_move = client.clone();
    let keydown_callback = Closure::<dyn FnMut(_)>::new(move |event: KeyboardEvent| {
        let mut direction = None;
        match event.key().as_str() {
            "w" | "ArrowUp" => direction = Some("UP"),
            "s" | "ArrowDown" => direction = Some("DOWN"),
            "a" | "ArrowLeft" => direction = Some("LEFT"),
            "d" | "ArrowRight" => direction = Some("RIGHT"),
            _ => {}
        }

        if let (Some(dir), Some(player)) = (direction, my_player_clone_for_move.borrow().as_ref()) {
            event.prevent_default();
            let payload = MovePayload { player_id: player.id, direction: dir };
            let client_clone_inner = client_clone_for_move.clone();
            spawn_local(async move {
                let _ = client_clone_inner
                    .post(format!("{}/game/move", API_BASE_URL))
                    .json(&payload)
                    .send()
                    .await;
            });
        }
    });
    window().add_event_listener_with_callback("keydown", keydown_callback.as_ref().unchecked_ref())?;
    keydown_callback.forget();

    let game_state_clone_for_draw = game_state.clone();
    let drawing_loop_callback = Rc::new(RefCell::new(None));
    let g = drawing_loop_callback.clone();
    *g.borrow_mut() = Some(Closure::<dyn FnMut()>::new(move || {
        if let Some(state) = game_state_clone_for_draw.borrow().as_ref() {
            if let Some(player) = my_player.borrow().as_ref() {
                draw_game(&get_canvas_context(), state, player.id);
            }
        }
        request_animation_frame(drawing_loop_callback.borrow().as_ref().unwrap());
    }));
    request_animation_frame(g.borrow().as_ref().unwrap());
    
    let game_state_clone_for_poll = game_state;
    let game_loop_callback = Closure::<dyn FnMut()>::new(move || {
        let gs_clone = game_state_clone_for_poll.clone();
        let client_clone_inner = client.clone();
        spawn_local(async move {
            if let Ok(resp) = client_clone_inner.get(format!("{}/game", API_BASE_URL)).send().await {
                if let Ok(state) = resp.json::<GameState>().await {
                    *gs_clone.borrow_mut() = Some(state);
                }
            }
        });
    });
    window().set_interval_with_callback_and_timeout_and_arguments_0(game_loop_callback.as_ref().unchecked_ref(), 150)?;
    game_loop_callback.forget();


    Ok(())
}

// ===================================================================================
// FUNÇÕES AUXILIARES
// ===================================================================================

fn window() -> web_sys::Window { web_sys::window().expect("no global `window` exists") }
fn document() -> web_sys::Document { window().document().expect("should have a document on window") }
fn request_animation_frame(f: &Closure<dyn FnMut()>) {
    window().request_animation_frame(f.as_ref().unchecked_ref()).expect("should register `requestAnimationFrame` OK");
}
fn get_canvas_context() -> CanvasRenderingContext2d {
    let canvas = document().get_element_by_id("game-canvas").unwrap().dyn_into::<HtmlCanvasElement>().unwrap();
    canvas.get_context("2d").unwrap().unwrap().dyn_into::<CanvasRenderingContext2d>().unwrap()
}

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

fn draw_game(ctx: &CanvasRenderingContext2d, state: &GameState, my_id: PlayerId) {
    let canvas = ctx.canvas().unwrap();
    let cell_width = (canvas.width() as f64 / state.width as f64).max(1.0);
    let cell_height = (canvas.height() as f64 / state.height as f64).max(1.0);

    ctx.set_fill_style(&JsValue::from_str("#34495e"));
    ctx.fill_rect(0.0, 0.0, canvas.width() as f64, canvas.height() as f64);

    for (y, row) in state.grid.iter().enumerate() {
        for (x, cell) in row.iter().enumerate() {
            let color = match cell {
                CellState::Neutral => "#7f8c8d".to_string(),
                CellState::Owned(id) => state.players.get(id).map_or("#bdc3c7".to_string(), |p| p.color.clone()),
            };
            ctx.set_fill_style(&JsValue::from_str(&color));
            ctx.fill_rect(x as f64 * cell_width, y as f64 * cell_height, cell_width, cell_height);
        }
    }

    for player in state.players.values() {
        let center_x = player.x as f64 * cell_width + cell_width / 2.0;
        let center_y = player.y as f64 * cell_height + cell_height / 2.0;
        
        ctx.begin_path();
        ctx.arc(center_x, center_y, cell_width / 2.5, 0.0, std::f64::consts::PI * 2.0).unwrap();
        ctx.set_fill_style(&JsValue::from_str(&player.color));
        ctx.fill();
        ctx.set_stroke_style(&JsValue::from_str("white"));
        ctx.set_line_width(2.0);
        ctx.stroke();

        if player.id == my_id {
            ctx.begin_path();
            ctx.arc(center_x, center_y, cell_width / 5.0, 0.0, std::f64::consts::PI * 2.0).unwrap();
            ctx.set_fill_style(&JsValue::from_str("white"));
            ctx.fill();
        }
    }
    
    match state.status {
        GameStatus::WaitingForPlayers => log(&format!("Aguardando jogadores... ({}/{})", state.players.len(), 2)),
        GameStatus::InProgress => log(&format!("Jogo em andamento! Você é o Jogador {}", my_id)),
        GameStatus::Finished => log("Fim de jogo!"),
    }
}
