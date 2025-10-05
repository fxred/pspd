use super::drawing::draw_game;
use super::utils::*;
use game_kernel::*;
use std::cell::RefCell;
use std::rc::Rc;
use wasm_bindgen::prelude::*;
use wasm_bindgen_futures::spawn_local;
use web_sys::KeyboardEvent;

const API_BASE_URL: &str = "http://127.0.0.1:8082";

pub async fn run_app() -> Result<(), JsValue> {
    let my_player: Rc<RefCell<Option<Player>>> = Rc::new(RefCell::new(None));
    let game_state: Rc<RefCell<Option<GameState>>> = Rc::new(RefCell::new(None));

    let client = reqwest::Client::new();
    log("Tentando entrar no jogo em /game/join...");
    
    let resp = client
        .post(format!("{}/game/join", API_BASE_URL))
        .send()
        .await
        .map_err(|e| JsValue::from_str(&format!("Erro de rede: {}", e)))?;
    
    if resp.status().is_success() {
        let join_response = resp.json::<JoinResponse>().await
            .map_err(|e| JsValue::from_str(&format!("Erro ao decodificar JSON: {}", e)))?;
        
        if !join_response.error.is_empty() {
            return Err(JsValue::from_str(&format!("Erro: {}", join_response.error)));
        }
        
        log(&format!("Entrou como Jogador {}", join_response.player.id));
        *my_player.borrow_mut() = Some(join_response.player);
    } else {
        let err_text = resp.text().await
            .map_err(|e| JsValue::from_str(&format!("Erro ao ler resposta: {}", e)))?;
        return Err(JsValue::from_str(&format!("Falha ao entrar: {}", err_text)));
    }
    
    let my_player_clone = my_player.clone();
    let client_clone = client.clone();
    let keydown_callback = Closure::<dyn FnMut(_)>::new(move |event: KeyboardEvent| {
        let direction = match event.key().as_str() {
            "w" | "ArrowUp" => Some("UP"),
            "s" | "ArrowDown" => Some("DOWN"),
            "a" | "ArrowLeft" => Some("LEFT"),
            "d" | "ArrowRight" => Some("RIGHT"),
            _ => None,
        };

        if let (Some(dir), Some(player)) = (direction, my_player_clone.borrow().as_ref()) {
            event.prevent_default();
            let payload = MovePayload {
                player_id: player.id,
                direction: dir.to_string(),
            };
            
            let client_inner = client_clone.clone();
            spawn_local(async move {
                let _ = client_inner
                    .post(format!("{}/game/move", API_BASE_URL))
                    .json(&payload)
                    .send()
                    .await;
            });
        }
    });
    
    window()
        .add_event_listener_with_callback("keydown", keydown_callback.as_ref().unchecked_ref())?;
    keydown_callback.forget();

    // Drawing loop
    let game_state_clone = game_state.clone();
    let my_player_clone = my_player.clone();
    let drawing_loop = Rc::new(RefCell::new(None));
    let g = drawing_loop.clone();
    
    *g.borrow_mut() = Some(Closure::<dyn FnMut()>::new(move || {
        if let (Some(state), Some(player)) = (
            game_state_clone.borrow().as_ref(),
            my_player_clone.borrow().as_ref()
        ) {
            draw_game(&get_canvas_context(), state, player.id);
        }
        request_animation_frame(drawing_loop.borrow().as_ref().unwrap());
    }));
    
    request_animation_frame(g.borrow().as_ref().unwrap());
    
    let game_state_clone_for_poll = game_state;
    let poll_callback = Rc::new(RefCell::new(None));
    let p = poll_callback.clone();

    *p.borrow_mut() = Some(Closure::<dyn FnMut()>::new(move || {
        let gs_clone = game_state_clone_for_poll.clone();
        let client_clone_inner = client.clone();
        let poll_callback_clone = poll_callback.clone();

        spawn_local(async move {
            let mut next_delay_ms = 1000;

            if let Ok(resp) = client_clone_inner.get(format!("{}/game/state", API_BASE_URL)).send().await {
                log(&format!("requisiação do game/state"));
                if let Ok(response) = resp.json::<StateResponse>().await {
                    let state = response.state; // Extrai o GameState de dentro da resposta
                    log(&format!("status {:?}", state.status));
                    match state.status {
                        GameStatus::WaitingForPlayers => {
                            log("Aguardando mais jogadores para começar...");
                            next_delay_ms = 2000;
                        },
                        GameStatus::InProgress => {
                            next_delay_ms = 35;
                        },
                        GameStatus::Finished => {
                            log("Jogo encerrado. Parando requisições.");
                            *gs_clone.borrow_mut() = Some(state);
                            return;
                        }
                    }
                    *gs_clone.borrow_mut() = Some(state);
                }
            }

            if let Some(next_poll) = poll_callback_clone.borrow().as_ref() {
                set_timeout(next_poll, next_delay_ms);
            }
        });

    }));

    if let Some(initial_poll) = p.borrow().as_ref() {
        set_timeout(initial_poll, 0);
    }

    Ok(())
}