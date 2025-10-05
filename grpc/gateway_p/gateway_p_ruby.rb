require 'sinatra'
require 'json'
require 'grpc'
require 'rack/cors'

$LOAD_PATH.unshift(File.expand_path('./lib', __dir__))

require 'service_b/game_state_pb'
require 'service_b/game_state_services_pb'
require 'service_a/game_movement_pb'
require 'service_a/game_movement_services_pb'

GAMESTATE_GRPC_ADDRESS = 'localhost:50051'
GAMEMOVE_GRPC_ADDRESS  = 'localhost:50052'

$game_state_stub = Gamestate::GameStateService::Stub.new(
  GAMESTATE_GRPC_ADDRESS,
  :this_channel_is_insecure
)
$game_move_stub = Gamemovement::GameMoveService::Stub.new(
  GAMEMOVE_GRPC_ADDRESS,
  :this_channel_is_insecure
)

class GameHTTPBridge < Sinatra::Base
  use Rack::Cors do
    allow do
      origins '*'
      resource '*', headers: :any, methods: [:get, :post, :options]
    end
  end

  set :port, 8082
  set :bind, '0.0.0.0'

  before do
    content_type 'application/json'
  end

  post '/game/join' do
    resp = $game_state_stub.join_game(Gamestate::JoinGameRequest.new)
    { player: resp.player.to_h, error: resp.error }.to_json
  rescue => e
    status 500
    { error: e.message }.to_json
  end

  get '/game/state' do
    resp = $game_state_stub.get_game_state(Gamestate::GetGameStateRequest.new)
    { state: resp.state.to_h }.to_json
  rescue => e
    status 500
    { error: e.message }.to_json
  end

  post '/game/move' do
    body = JSON.parse(request.body.read)
    
    player_id = body['player_id']
    direction_str = body['direction']
    
    direction = case direction_str
                when 'UP' then :UP
                when 'DOWN' then :DOWN
                when 'LEFT' then :LEFT
                when 'RIGHT' then :RIGHT
                else
                  status 400
                  return { error: 'Invalid direction' }.to_json
                end

    req = Gamemovement::ExecuteMoveRequest.new(
      player_id: player_id,
      direction: direction
    )
    
    resp = $game_move_stub.execute_move(req)
    {
      new_state: resp.new_state&.to_h,
      game_finished: resp.game_finished,
      error: resp.error
    }.to_json
  rescue => e
    status 500
    { error: e.message }.to_json
  end

  get '/' do
    {
      service: 'Gateway HTTP do Jogo',
      description: 'Proxy HTTP para serviços gRPC GameMoveService & GameStateService',
      endpoints: [
        'POST /game/join    -> Service B (GameStateService)',
        'GET  /game/state   -> Service B (GameStateService)',
        'POST /game/move    -> Service A (GameMoveService)'
      ]
    }.to_json
  end
end

if __FILE__ == $0
  puts "Gateway HTTP do Jogo está iniciando..."
  puts "Conectando ao Serviço B (Estado):    #{GAMESTATE_GRPC_ADDRESS}"
  puts "Conectando ao Serviço A (Movimento): #{GAMEMOVE_GRPC_ADDRESS}"
  puts "API HTTP disponível em: http://localhost:8082"
  puts ""
  GameHTTPBridge.run!
end