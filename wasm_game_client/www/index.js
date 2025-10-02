import init from './pkg/wasm_game_client.js';

async function run() {
  try {
    // A função init carrega o .wasm e executa a função marcada com `#[wasm_bindgen(start)]`
    await init();
  } catch (error) {
    console.error("Erro fatal ao inicializar o módulo WebAssembly:", error);
  }
}

run();
