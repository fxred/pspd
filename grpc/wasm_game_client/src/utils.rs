use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;
use web_sys::{CanvasRenderingContext2d, HtmlCanvasElement};

pub fn window() -> web_sys::Window { web_sys::window().expect("no global `window` exists") }
pub fn document() -> web_sys::Document { window().document().expect("should have a document on window") }
pub fn request_animation_frame(f: &Closure<dyn FnMut()>) {
    window().request_animation_frame(f.as_ref().unchecked_ref()).expect("should register `requestAnimationFrame` OK");
}
pub fn get_canvas_context() -> CanvasRenderingContext2d {
    let canvas = document().get_element_by_id("game-canvas").unwrap().dyn_into::<HtmlCanvasElement>().unwrap();
    canvas.get_context("2d").unwrap().unwrap().dyn_into::<CanvasRenderingContext2d>().unwrap()
}

pub fn set_timeout(f: &Closure<dyn FnMut()>, timeout_ms: i32) {
    window()
        .set_timeout_with_callback_and_timeout_and_arguments_0(f.as_ref().unchecked_ref(), timeout_ms)
        .expect("should register `setTimeout` OK");
}

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    pub fn log(s: &str);
}