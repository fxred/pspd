import init, { App } from './pkg/wasm_game_client.js';

async function run() {
  try {
    await init();

    const apiPort = '8000'; 
    const apiBaseUrl = `http://${window.location.hostname}:${apiPort}`;

    console.log(`API URL: ${apiBaseUrl}`);

    const app = new App(apiBaseUrl);
    await app.run_app();

  } catch (error) {
    console.error("Erro fatal ao inicializar ou executar a aplicação:", error);
  }
}

run();
