require 'sinatra'
require 'json'
require 'grpc'

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))

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
  include Swagger::Blocks

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

  post 'game/join' do
    resp = $game_state_stub.join_game(Gamestate::JoinGameRequest.new)

    game_state_resp = $game_state_stub.get_game_state(Gamestate::GetGameStateRequest.new)
    current_state = game_state_resp.state

    if current_state.players.size >= 2 && current_state.status != :IN_PROGRESS
      current_state.status = :IN_PROGRESS
      $game_state_stub.update_game_state(Gamestate::UpdateGameStateRequest.new(state: current_state))
    end

    {
      player: resp.player.to_h,
      error: resp.error,
      total_players: current_state.players.size,
      game_status: current_state.status
    }.to_json
  rescue => e
    status 500
    { error: e.message }.to_json
  end

  get 'game/state' do
    resp = $game_state_stub.get_game_state(Gamestate::GetGameStateRequest.new)
    { state: resp.state.to_h }.to_json
  rescue => e
    status 500
    { error: e.message }.to_json
  end

  post 'game/update_state' do
    body = JSON.parse(request.body.read)
    gs = Gamestate::GameState.decode_json(body['state'].to_json)

    gs.status = gs.players.size >= 2 ? :IN_PROGRESS : :WAITING_FOR_PLAYERS

    resp = $game_state_stub.update_game_state(Gamestate::UpdateGameStateRequest.new(state: gs))
    { success: resp.success, current_status: gs.status }.to_json
  rescue => e
    status 500
    { error: e.message }.to_json
  end

  post 'game/create' do
    body = JSON.parse(request.body.read) rescue {}
    width  = body['width']  || 5
    height = body['height'] || 5

    grid_rows = Array.new(height) do
      Gamestate::GridRow.new(
        cells: Array.new(width) { Gamestate::Cell.new(state: :NEUTRAL, owner_id: 0) }
      )
    end

    new_state = Gamestate::GameState.new(
      status: :WAITING_FOR_PLAYERS,
      width: width,
      height: height,
      grid: Gamestate::Grid.new(rows: grid_rows),
      players: {}
    )

    resp = $game_state_stub.update_game_state(Gamestate::UpdateGameStateRequest.new(state: new_state))
    { success: resp.success, created_state: new_state.to_h }.to_json
  rescue => e
    status 500
    { error: e.message }.to_json
  end

  post 'game/validate_move' do
    body = JSON.parse(request.body.read)
    req = Gamemovement::ValidateMoveRequest.decode_json(body.to_json)
    resp = $game_move_stub.validate_move(req)
    { is_valid: resp.is_valid, error: resp.error }.to_json
  rescue => e
    status 500
    { error: e.message }.to_json
  end

  post 'game/execute_move' do
    body = JSON.parse(request.body.read)
    req = Gamemovement::ExecuteMoveRequest.decode_json(body.to_json)
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

  post 'game/valid_moves' do
    body = JSON.parse(request.body.read)
    req = Gamemovement::GetValidMovesRequest.decode_json(body.to_json)
    resp = $game_move_stub.get_valid_moves(req)
    { valid_moves: resp.valid_moves.map(&:to_h) }.to_json
  rescue => e
    status 500
    { error: e.message }.to_json
  end

  get '/' do
    {
      service: 'Gateway HTTP do Jogo',
      description: 'Ponte para serviço REST HTTP do Jogo para gRPC GameMoveService & GameStateService',
      rule: 'O jogo só começa quando 2 ou mais jogadores se juntam',
      endpoints: [
        'POST game/create',
        'POST game/join',
        'GET  game/state',
        'POST game/update_state',
        'POST game/validate_move',
        'POST game/execute_move',
        'POST game/valid_moves'
      ]
    }.to_json
  end
end

if __FILE__ == $0
  puts "Gateway HTTP do Jogo está iniciando..."
  puts "Conectando ao Serviço A (Movimento):  #{GAMEMOVE_GRPC_ADDRESS}"
  puts "Conectando ao Serviço B (Estado): #{GAMESTATE_GRPC_ADDRESS}"
  puts "API HTTP disponível em: http://localhost:8080"
  puts ""
  GameHTTPBridge.run!
end