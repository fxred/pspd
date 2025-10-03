
use wasm_bindgen::prelude::*;

mod app;
mod drawing;
mod utils;


#[wasm_bindgen(start)]
pub async fn main_wasm() {
    console_error_panic_hook::set_once();

    if let Err(e) = app::run_app().await {
        utils::log(&format!("Erro crítico durante a inicialização: {:?}", e));
    }
}