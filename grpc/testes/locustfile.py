from locust import HttpUser, task, between, events
import random
import json

class StressUser(HttpUser):
    # Tempo de espera entre ações (simula velocidade humana ou bot rápido)
    # Para stress, use valores baixos (0.1 a 1). Para simular humanos, (1 a 3)
    wait_time = between(0.5, 2)
    
    player_id = None
    
    def on_start(self):
        """
        Executado uma vez quando o usuário 'nasce'.
        Tenta entrar no jogo (Join).
        """
        self.join_game()

    def join_game(self):
        try:
            # O catch_response=True permite que a gente marque falhas manualmente
            with self.client.post("/game/join", catch_response=True) as response:
                if response.status_code == 200:
                    try:
                        data = response.json()
                        # Tenta pegar o ID de várias formas possíveis (camelCase ou snake_case)
                        self.player_id = data.get("player").get("id")
                        
                        if self.player_id:
                            # print(f"✅ Jogador {self.player_id} entrou com sucesso.")
                            response.success()
                        else:
                            print(f"❌ Erro: JSON sem ID -> {data}")
                            response.failure("JSON returned no player_id")
                    except json.JSONDecodeError:
                        print("❌ Erro: Resposta não é um JSON válido")
                        response.failure("Response not JSON")
                else:
                    print(f"❌ Falha no Join: Status {response.status_code}")
                    response.failure(f"Status code: {response.status_code}")
        except Exception as e:
            print(f"❌ Erro de conexão no Join: {e}")

    @task(10) # Peso 10 (acontece muito)
    def make_move(self):
        """
        Envia um movimento para o servidor.
        """
        # Se por algum motivo o on_start falhou, tenta entrar de novo e não move agora
        if not self.player_id:
            self.join_game()
            return

        directions = ["UP", "DOWN", "LEFT", "RIGHT"]
        direction = random.choice(directions)
        
        payload = {
            "player_id": self.player_id,
            "direction": direction
        }
        
        # Headers explícitos as vezes ajudam se o Ruby for chato
        headers = {'Content-Type': 'application/json'}

        with self.client.post("/game/move", json=payload, headers=headers, catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            elif response.status_code == 500:
                # Se der erro 500, o Locust registra, mas o bot continua vivo
                response.failure("Internal Server Error")
            else:
                response.failure(f"Move Error: {response.status_code}")

    @task(10) # Peso 1 (acontece pouco)
    def view_state(self):
        """
        Apenas visualiza o estado (gera carga de leitura no Service B).
        """
        self.client.get("/game/state")

# Listener apenas para mensagem de inicio
@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    print("=" * 60)
    print("🚀 INICIANDO STRESS TEST - MODO MAPA INFINITO")
    print("=" * 60)