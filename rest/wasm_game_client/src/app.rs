use super::drawing::draw_game;
use super::utils::*; 
use game_kernel::*;
use std::cell::RefCell;
use std::rc::Rc;
use wasm_bindgen::prelude::*;
use wasm_bindgen_futures::spawn_local;
use web_sys::KeyboardEvent;


#[wasm_bindgen]
pub struct App {
    api_base_url: String,
    client: reqwest::Client,
    my_player: Rc<RefCell<Option<Player>>>,
    game_state: Rc<RefCell<Option<GameState>>>,
}

fn setup_keyboard_listener(app: Rc<App>) -> Result<(), JsValue> {
    let keydown_callback = Closure::<dyn FnMut(_)>::new(move |event: KeyboardEvent| {
        if let Some(state) = app.game_state.borrow().as_ref() {
            if state.status != GameStatus::InProgress {
                return;
            }
        } else {
            return;
        }

        let mut direction = None;
        match event.key().as_str() {
            "w" | "ArrowUp" => direction = Some("UP"),
            "s" | "ArrowDown" => direction = Some("DOWN"),
            "a" | "ArrowLeft" => direction = Some("LEFT"),
            "d" | "ArrowRight" => direction = Some("RIGHT"),
            _ => {}
        }

        if let (Some(dir), Some(player)) = (direction, app.my_player.borrow().as_ref()) {
            event.prevent_default();
            let payload = MovePayload { player_id: player.id, direction: dir.to_string() };
            let client_clone = app.client.clone();
            let api_base_url = app.api_base_url.clone();
            spawn_local(async move {
                let _ = client_clone
                    .post(format!("{}/game/move", api_base_url))
                    .json(&payload)
                    .send()
                    .await;
            });
        }
    });

    window().add_event_listener_with_callback("keydown", keydown_callback.as_ref().unchecked_ref())?;
    keydown_callback.forget();
    Ok(())
}

fn setup_drawing_loop(app: Rc<App>) {
    let drawing_loop_callback = Rc::new(RefCell::new(None));
    let g = drawing_loop_callback.clone();

    *g.borrow_mut() = Some(Closure::<dyn FnMut()>::new(move || {
        if let Some(state) = app.game_state.borrow().as_ref() {
            if let Some(player) = app.my_player.borrow().as_ref() {
                draw_game(&get_canvas_context(), state, player.id);
            }
        }
        request_animation_frame(drawing_loop_callback.borrow().as_ref().unwrap());
    }));

    request_animation_frame(g.borrow().as_ref().unwrap());
}

fn setup_polling_loop(app: Rc<App>) {
    let poll_callback = Rc::new(RefCell::new(None));
    let p = poll_callback.clone();

    *p.borrow_mut() = Some(Closure::<dyn FnMut()>::new(move || {
        let app_clone = app.clone();
        let poll_callback_clone = poll_callback.clone();

        spawn_local(async move {
            let mut next_delay_ms = 1000;
            let url = format!("{}/game/state", app_clone.api_base_url);

            if let Ok(resp) = app_clone.client.get(&url).send().await {
                if let Ok(state) = resp.json::<GameState>().await {
                    match state.status {
                        GameStatus::WaitingForPlayers => {
                            log("Aguardando mais jogadores para começar...");
                            next_delay_ms = 2000;
                        },
                        GameStatus::InProgress => {
                            next_delay_ms = 2;
                        },
                        GameStatus::Finished => {
                            log("Jogo encerrado. Parando requisições.");
                            *app_clone.game_state.borrow_mut() = Some(state);
                            return;
                        }
                    }
                    *app_clone.game_state.borrow_mut() = Some(state);
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
}

#[wasm_bindgen]
impl App {
    #[wasm_bindgen(constructor)]
    pub fn new(api_base_url: String) -> Self {
        App {
            api_base_url,
            client: reqwest::Client::new(),
            my_player: Rc::new(RefCell::new(None)),
            game_state: Rc::new(RefCell::new(None)),
        }
    }

    #[wasm_bindgen]
    pub async fn run_app(self) -> Result<(), JsValue> {
        log("Tentando entrar no jogo em /game/join...");
        
        let resp = self.client.post(format!("{}/game/join", self.api_base_url)).send().await
            .map_err(|e| JsValue::from_str(&format!("Erro de rede ao tentar /join: {}", e)))?;
        
        if resp.status().is_success() {
            let player = resp.json::<Player>().await
                .map_err(|e| JsValue::from_str(&format!("Erro ao decodificar JSON do jogador: {}", e)))?;
            log(&format!("Entrou com sucesso como Jogador {}", player.id));
            *self.my_player.borrow_mut() = Some(player);
        } else {
            let err_text = resp.text().await
                .map_err(|e| JsValue::from_str(&format!("Erro ao ler corpo da resposta de erro: {}", e)))?;
            return Err(JsValue::from_str(&format!("Falha ao entrar no jogo: {}", err_text)));
        }
        
        let app_rc = Rc::new(self);

        setup_keyboard_listener(app_rc.clone())?;
        setup_drawing_loop(app_rc.clone());
        setup_polling_loop(app_rc);

        Ok(())
    }
}