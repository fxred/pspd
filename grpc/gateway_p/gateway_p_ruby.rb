require 'sinatra/base'
require 'json'
require 'grpc'
require 'google/protobuf/well_known_types'


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

  set :port, 8082
  set :bind, '0.0.0.0'
  set :host_authorization, permitted_hosts: []

  before do
    content_type 'application/json'
  end

  post '/game/join' do
    resp = $game_state_stub.join_game(Gamestate::JoinGameRequest.new)
    Google::Protobuf.encode_json(resp, emit_defaults: true)
  rescue => e
    status 500
    { error: e.message }.to_json
  end

  get '/game/state' do
    resp = $game_state_stub.get_game_state(Gamestate::GetGameStateRequest.new)
    Google::Protobuf.encode_json(resp, emit_defaults: true)
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

    begin
        current_state_response = $game_state_stub.get_game_state(Gamestate::GetGameStateRequest.new)
        current_state = current_state_response.state
    rescue GRPC::Unavailable => e
        status 503
        return { error: "Serviço de estado do jogo indisponível: #{e.message}" }.to_json
    end


	current_state_hash = current_state.to_h
	
    req = Gamemovement::ExecuteMoveRequest.new(
      current_state: current_state_hash,
      player_id: player_id,
      direction: direction
    )
    
    resp = $game_move_stub.execute_move(req)
    Google::Protobuf.encode_json(resp, emit_defaults: true)
  rescue => e
    status 500
    puts "!!!!!!!!!!!!! ERRO DETALHADO !!!!!!!!!!!!!"
    puts e.full_message
    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
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
