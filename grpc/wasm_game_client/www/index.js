import init from './pkg/wasm_game_client.js';

async function run() {
  try {
    await init();
  } catch (error) {
    console.error("Erro fatal ao inicializar o módulo WebAssembly:", error);
  }
}

run();
