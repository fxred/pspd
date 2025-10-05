use super::drawing::draw_game;
use super::utils::*;
use game_kernel::*;
use serde::Deserialize; // <-- Adicionado para deserializar as respostas JSON
use std::cell::RefCell;
use std::rc::Rc;
use wasm_bindgen::prelude::*;
use wasm_bindgen_futures::spawn_local;
use web_sys::KeyboardEvent;

// Structs para corresponder à estrutura do JSON retornado pela API
#[derive(Deserialize)]
struct JoinResponse {
    player: Player,
}

#[derive(Deserialize)]
struct StateResponse {
    state: GameState,
}

const API_BASE_URL: &str = "http://127.0.0.1:8082";

pub async fn run_app() -> Result<(), JsValue> {
    let my_player: Rc<RefCell<Option<Player>>> = Rc::new(RefCell::new(None));
    let game_state: Rc<RefCell<Option<GameState>>> = Rc::new(RefCell::new(None));

    let client = reqwest::Client::new();
    log("Tentando entrar no jogo em /game/join...");
    
    let resp = client.post(format!("{}/game/join", API_BASE_URL)).send().await
        .map_err(|e| JsValue::from_str(&format!("Erro de rede ao tentar /join: {}", e)))?;
    
    if resp.status().is_success() {
        let join_response = resp.json::<JoinResponse>().await
            .map_err(|e| JsValue::from_str(&format!("Erro ao decodificar JSON da resposta de join: {}", e)))?;
        log(&format!("Entrou com sucesso como Jogador {}", join_response.player.id));
        *my_player.borrow_mut() = Some(join_response.player);
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
            let payload = MovePayload { player_id: player.id, direction: dir.to_string() };
            let client_clone_inner = client_clone_for_move.clone();
            spawn_local(async move {
                let _ = client_clone_inner
                    .post(format!("{}/game/execute_move", API_BASE_URL))
                    .json(&payload)
                    .send()
                    .await;
            });
        }
    });
    window().add_event_listener_with_callback("keydown", keydown_callback.as_ref().unchecked_ref())?;
    keydown_callback.forget();

    let game_state_clone_for_draw = game_state.clone();
    let my_player_clone_for_draw = my_player.clone();
    let drawing_loop_callback = Rc::new(RefCell::new(None));
    let g = drawing_loop_callback.clone();
    *g.borrow_mut() = Some(Closure::<dyn FnMut()>::new(move || {
        if let Some(state) = game_state_clone_for_draw.borrow().as_ref() {
            if let Some(player) = my_player_clone_for_draw.borrow().as_ref() {
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
            if let Ok(resp) = client_clone_inner.get(format!("{}/game/state", API_BASE_URL)).send().await {
                if let Ok(state_response) = resp.json::<StateResponse>().await {
                    *gs_clone.borrow_mut() = Some(state_response.state);
                }
            }
        });
    });
    window().set_interval_with_callback_and_timeout_and_arguments_0(game_loop_callback.as_ref().unchecked_ref(), 35)?;
    game_loop_callback.forget();

    Ok(())
}