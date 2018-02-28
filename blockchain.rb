require 'digest'

class Block
  def initialize(index, previous_hash, timestamp, data, hash)
    @index = index
    @previousHash = previous_hash
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
  Digest::SHA256.digest(
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
end