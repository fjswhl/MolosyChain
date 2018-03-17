require 'pp'
require 'json'
require_relative 'block'
require_relative 'transaction'
require_relative 'wallet'

class BlockChain

  attr_accessor :blocks

  BLOCK_GENERATION_INTERVAL = 10

  DIFFICULTY_ADJUSTMENT_INTERVAL = 10

  def initialize
    @blocks = [Block.genesis_block]
    @unspent_tx_outs = []
  end

  def get_latest_block
    @blocks[@blocks.length - 1]
  end

  def generate_next_block
    coinbase_tx = get_coinbase_transaction(get_public_from_wallet, get_latest_block.index + 1)
    generate_raw_next_block([coinbase_tx])
  end

  def generate_next_block_with_transaction(receiver_address, amount)
    coinbase_tx = get_coinbase_transaction(get_public_from_wallet, get_latest_block.index + 1)
    tx = create_transaction(receiver_address, amount, get_private_from_wallet, @unspent_tx_outs)
    generate_raw_next_block([coinbase_tx, tx])
  end

  def generate_raw_next_block(block_data)
    previous_block = get_latest_block
    next_index = previous_block.index + 1
    next_time_stamp = Time.now.to_i

    block = find_block(next_index, previous_block.hash, next_time_stamp, block_data, difficulty)
    if add_block(block)
      yield
      return block
    else
      return nil
    end
  end

  def find_block(index, previous_hash, timestamp, data, difficulty)
    nonce = 0
    pp 'current difficulty ' + difficulty.to_s
    loop do
      hash = Block.calculate_hash(index, previous_hash, timestamp, data, difficulty, nonce)
      if hash_matches_difficulty(hash, difficulty)
        return Block.new(index, previous_hash, timestamp, data, hash, difficulty, nonce)
      end
      nonce = nonce + 1
    end
  end

  def add_block(new_block)
    if new_block.is_valid_next_block?(get_latest_block)
      updated_unspent_outs = process_transactions(new_block.data, @unspent_tx_outs, new_block.index)
      if updated_unspent_outs.nil?
        return false
      else
        @blocks.push(new_block)
        @unspent_tx_outs = updated_unspent_outs
        return true
      end
    end

    false
  end

  def self.is_valid_blocks?(blocks)
    if blocks[0].to_json != Block.genesis_block.to_json
      return false
    end

    for i in 1..blocks.length - 1 do
      unless blocks[i].is_valid_next_block?(blocks[i - 1])
        return false
      end
    end

    return true
  end

  def replace_chain(new_blocks)
    if BlockChain.is_valid_blocks?(new_blocks) &&  accumulated_difficulty(new_blocks) > accumulated_difficulty(@blocks)
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
      return get_latest_block.difficulty
    end
  end

  def adjusted_difficulty
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

  def hex_to_binary(hex)
    lookup_table = {
        '0' => '0000', '1' => '0001', '2' => '0010', '3' => '0011', '4' => '0100',
        '5' => '0101', '6' => '0110', '7' => '0111', '8' => '1000', '9' => '1001',
        'a' => '1010', 'b' => '1011', 'c' => '1100', 'd' => '1101', 'e' => '1110', 'f' => '1111'
    }

    res = ''

    for i in 0..hex.length - 1
      if lookup_table[hex[i]]
        res = res + lookup_table[hex[i]]
      else
        return nil
      end
    end

    res
  end

  def hash_matches_difficulty(hash, difficulty)
    hash_in_binary = hex_to_binary(hash)
    required_prefix = ''
    for i in 0..difficulty
      required_prefix = required_prefix + '0'
    end

    hash_in_binary.start_with?(required_prefix)
  end

  def accumulated_difficulty(blocks)
    blocks.map { |block| block.difficulty }
      .map { |difficulty| 2**difficulty }
      .reduce(:+)
  end
end



