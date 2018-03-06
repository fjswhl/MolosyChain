require 'websocket-eventmachine-client'
require 'websocket-eventmachine-server'

module MessageType
  QUERY_LATEST = 0
  QUERY_ALL = 1
  RESPONSE_BLOCKCHAIN = 2
end

class P2PNetwork
  attr_accessor :blockchain

  def initialize(server_port, initial_peers, blockchain)
    @sockets = []
    @server_port = server_port
    @initial_peers = initial_peers || []
    @blockchain = blockchain
  end

  def start
    connect_to_peers(@initial_peers)
    init_p2p_server
  end

  def connect_to_peers(new_peers)
    new_peers.each do |p|
      ws = WebSocket::EventMachine::Client.connect(:uri => p)

      init_p2p_connections(ws)

      ws.onerror do
        pp 'connection failed'
      end
    end
  end

  def init_p2p_server
    WebSocket::EventMachine::Server.start(:host => "0.0.0.0", :port => @server_port) do |ws|
      @sockets.push(ws)

      init_p2p_connections(ws)

      ws.onopen do
        pp 'connected'
        write(ws, query_chain_length_msg)
      end

      ws.onclose do
        @sockets.delete(ws)
      end

      ws.onerror do
        @sockets.delete(ws)
      end
    end
  end

  def init_p2p_connections(ws)
    ws.onmessage do |data, type|
      message = JSON.parse(data)
      pp 'Received message' + message.to_s
      case message['type']
        when MessageType::QUERY_LATEST
          write(ws, response_latest_msg)
        when MessageType::QUERY_ALL
          write(ws, response_chain_msg)
        when MessageType::RESPONSE_BLOCKCHAIN
          handle_blockchain_response(message)
      end
    end
  end

  def write(ws, message)
    ws.send(message.to_json)
  end

  def broadcast(message)
    @sockets.each do |ws|
      write(ws, message)
    end
  end

  def broadcast_response_latest_msg
    broadcast(response_latest_msg)
  end

  def response_chain_msg
    { :type => MessageType::RESPONSE_BLOCKCHAIN, :data => @blockchain.blocks }
  end

  def response_latest_msg
    { :type => MessageType::RESPONSE_BLOCKCHAIN, :data => [@blockchain.get_latest_block] }
  end

  def query_all_msg
    { :type => MessageType::QUERY_ALL }
  end

  def query_chain_length_msg
    { :type => MessageType::QUERY_LATEST }
  end

  def handle_blockchain_response(message)
    received_blocks = message['data'].sort { |x, y| x - y }
    latest_block_received = Block.from_dic(received_blocks[received_blocks.length - 1])
    latest_block_held = blockchain.get_latest_block

    if latest_block_received.index > latest_block_held.index
      if latest_block_held.hash == latest_block_received.previous_hash
        @blockchain.blocks.push(latest_block_received)
        broadcast(response_latest_msg)
      elsif received_blocks.length == 1
        broadcast(query_all_msg)
      else
        @blockchain.replace_chain(received_blocks) do |b|
          broadcast_response_latest_msg
        end
      end
    else
      pp 'received blockchain is not longer than current blockchain. Do nothing'
    end
  end
end