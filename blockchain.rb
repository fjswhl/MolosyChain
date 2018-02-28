require 'digest'
require 'pp'
require 'websocket-eventmachine-client'
require 'websocket-eventmachine-server'
require 'json'

class Block
  def initialize(index, previous_hash, timestamp, data, hash)
    @index = index
    @previous_hash = previous_hash
    @timestamp = timestamp
    @data = data
    @hash = hash
  end 
end

def get_genesis_block
  Block.new0(0, "0", 1465154705, "my genesis block!!", "816534932c2b7154836da6afc367695e6337db8a921823784c14378abed4f7d7")
end

blockchain = [get_genesis_block]

def get_latest_block
  blockchain[blockchain.length - 1]  
end

def calculate_hash(index, previous_hash, timestamp, data)
  Digest::SHA256.hexdigest(
    index.to_s +
    previous_hash.to_s +
    timestamp.to_s +
    data.to_s
  ).to_s
end

def calculate_hash_for_block(block)
  calculate_hash(block.index, block.previous_hash, block.timestamp, block.data)
end

def generate_next_block(block_data)
  previous_block = get_latest_block
  next_index = previous_block.index + 1
  next_time_stamp = Time.now.to_i
  next_hash = calculate_hash_for_block()
  return Block.new(next_index, previous_block.hash, next_time_stamp, block_data, next_hash)
end

def is_valid_new_block?(new_block, previous_block)
  if previous_block.index + 1 != new_block.index
    pp 'invalid index'
    return false
  elsif previous_block.hash != new_block.previous_hash
    pp 'invalid previoushash'
    return false
  elsif calculate_hash_for_block(new_block) != new_block.hash
    pp 'invalid hash: ' + calculate_hash_for_block(new_block) + ' ' + new_block.hash
    return false
  else
    return true
  end
end

def add_block(new_block)
  if is_valid_new_block(new_block, get_latest_block)
    blockchain.push(new_block)
  end
end

sockets = []
module MessageType
  QUERY_LATEST = 0
  QUERY_ALL = 1
  RESPONSE_BLOCKCHAIN = 2
end

def write(ws, message)
  ws.send(message.to_json)
end

def broadcast(message)
  sockets.each do |ws|
    write(ws, message)
  end
end

def response_chain_msg
  { :type => MessageType::RESPONSE_BLOCKCHAIN, :data => blockchain.to_json }
end

def response_latest_msg
  { :type => MessageType::RESPONSE_BLOCKCHAIN, :data => [get_latest_block].to_json }
end

def query_all_msg
  { :type => MessageType::QUERY_ALL }
end

def replace_chain(new_blocks)
  
end

def handle_blockchain_response(message)
  received_blocks = JSON.parse(message['data'].sort { |x, y| x - y })
  latest_block_received = received_blocks[received_blocks.length - 1]
  latest_block_held = get_latest_block
  if latest_block_received.index > latest_block_held.index
    if latest_block_held.hash == latest_block_received.previous_hash
      blockchain.push(latest_block_received)
      broadcast(response_latest_msg)
    elsif received_blocks.length == 1
      broadcast(query_all_msg)
    else
      replace_chain(received_blocks)
    end
  else
    pp 'received blockchain is not longer than current blockchain. Do nothing'
  end
end

def init_p2p_server
  WebSocket::EventMachine::Server.start(:host => "0.0.0.0", :port => 8080) do |ws|
    sockets.push(ws)

    ws.onmessage do |data, type|
      message = JSON.parse(data)
      pp 'Received message' + message
      case message['type']
      when MessageType::QUERY_LATEST
        write(ws, response_latest_msg)
      when MessageType::QUERY_ALL
        write(ws, response_chain_msg)
      when MessageType::RESPONSE_BLOCKCHAIN

    end

    ws.onclose do
      puts "Client disconnected"
    end
  end
end