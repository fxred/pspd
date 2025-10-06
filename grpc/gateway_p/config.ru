require 'rack/cors'
require 'rack/protection'
require_relative 'gateway_p_ruby'

use Rack::Protection::HostAuthorization, allow: []

use Rack::Cors do
  allow do
    origins '*'
    resource '*', headers: :any, methods: [:get, :post, :options]
  end
end

run GameHTTPBridge
