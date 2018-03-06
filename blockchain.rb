require 'pp'
require 'json'
require_relative 'block'

class BlockChain

  attr_accessor :blocks

  BLOCK_GENERATION_INTERVAL = 10

  DIFFICULTY_ADJUSTMENT_INTERVAL = 10

  def initialize
    @blocks = [Block.genesis_block]
  end

  def get_latest_block
    @blocks[@blocks.length - 1]
  end

  def generate_next_block(block_data)
    previous_block = get_latest_block
    next_index = previous_block.index + 1
    next_time_stamp = Time.now.to_i
    next_hash = Block.calculate_hash(next_index, previous_block.hash, next_time_stamp, block_data)
    Block.new(next_index, previous_block.hash, next_time_stamp, block_data, next_hash, difficulty)
  end

  def find_block(index, previous_hash, timestamp, data, difficulty)
    nonce = 0
    loop do
      hash = Block.calculate_hash(index, previous_hash, timestamp, data, difficulty, nonce)

    end
  end

  def add_block(new_block)
    if new_block.is_valid_next_block?(get_latest_block)
      @blocks.push(new_block)
    end
  end

  def self.is_valid_blocks?(blocks)
    if blocks[0].to_json == Block.genesis_block.to_json
      return false
    end

    for i in 1..blocks.length - 1 do
      unless blocks[i].is_valid_next_block?(blocks[i] - 1)
        return false
      end
    end

    return true
  end

  def replace_chain(new_blocks)
    if BlockChain.is_valid_blocks?(new_blocks) && new_blocks.length > @blocks.length
      pp 'Received blockchain is valid, Replacing current blockchain with received blockchain;'
      @blocks = new_blocks
      yield
    else
      pp 'Received blockchain is invalid'
    end
  end

  def difficulty
    if get_latest_block.index % DIFFICULTY_ADJUSTMENT_INTERVAL == 0 && get_latest_block.index != 0
      return adjusted_difficulty
    else
      return latest_block.difficulty
    end
  end

  def adjusted_difficuty
    prev_adjustment_block = @blocks[@blocks.length - DIFFICULTY_ADJUSTMENT_INTERVAL]
    time_expected = BLOCK_GENERATION_INTERVAL * DIFFICULTY_ADJUSTMENT_INTERVAL
    time_taken = get_latest_block.timestamp - prev_adjustment_block.timestamp

    if time_taken < time_expected / 2
      return prev_adjustment_block.difficulty + 1
    elsif time_taken > time_expected * 2
      return prev_adjustment_block.difficulty - 1
    else
      return prev_adjustment_block.difficulty
    end
  end
end



