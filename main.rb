require 'sinatra/base'
require 'thin'
require_relative 'blockchain'
require_relative 'p2p_network'

$initial_peers = ENV['PEERS'] ? ENV['PEERS'].split(',') : []
$http_port = ENV['HTTP_PORT'] || 3004
$p2p_port = ENV['P2P_PORT'] || 6004

class App < Sinatra::Base
  configure do
    set :threaded, false
  end
end

blockchain = BlockChain.new
p2p_network = P2PNetwork.new($p2p_port, $initial_peers, blockchain)

App.get '/blocks' do
  blockchain.blocks.to_json
end

App.post '/mineBlock' do
  data = JSON.parse(request.body.read)
  new_block = blockchain.generate_next_block(data['data'])
  blockchain.add_block(new_block)
  p2p_network.broadcast_response_latest_msg
  pp 'block added: ' + new_block.to_json
end

EM.run do

  dispatch = Rack::Builder.app do
    map '/' do
      run App.new
    end
  end

  Rack::Server.start({
                         app: dispatch,
                         server: 'thin',
                         Host: '0.0.0.0',
                         Port: $http_port,
                         signals: false
                     })

  p2p_network.start

end